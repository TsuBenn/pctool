class_name UpdateChecker
extends Node

## Configure your public GitHub repo details here
const GITHUB_OWNER: String = "TsuBenn"
const GITHUB_REPO: String = "pctool"

var _http_request: HTTPRequest
var _update_dialog: ConfirmationDialog
var _latest_release_url: String = ""


func _ready() -> void:
	# 1. Setup internal HTTPRequest node
	_http_request = HTTPRequest.new()
	add_child(_http_request)

	# Bypass strict local CA bundle checks on Windows for public GitHub GET requests
	_http_request.set_tls_options(TLSOptions.client_unsafe())

	_http_request.request_completed.connect(_on_request_completed)
	# 2. Setup ConfirmationDialog for update prompt
	_update_dialog = ConfirmationDialog.new()
	_update_dialog.title = "Update Available"
	_update_dialog.ok_button_text = "Download"
	_update_dialog.cancel_button_text = "Later"
	add_child(_update_dialog)
	_update_dialog.confirmed.connect(_on_update_confirmed)


## Triggers a background check against GitHub Releases API
func check_for_updates() -> void:
	if GITHUB_OWNER.begins_with("YOUR_") or GITHUB_REPO.begins_with("YOUR_"):
		# Skip check if placeholders haven't been replaced
		return

	var url: String = "https://api.github.com/repos/%s/%s/releases/latest" % [GITHUB_OWNER, GITHUB_REPO]

	# GitHub API strictly requires a User-Agent header
	var headers: PackedStringArray = [
		"User-Agent: PCTool-App",
		"Accept: application/vnd.github.v3+json"
	]

	_http_request.request(url, headers)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		# Fail silently on network errors so it never interrupts the user
		# Global.notice("Update Checker", "Failed to request HTTP! " + str(result))
		return

	var json: JSON = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return

	var data: Dictionary = json.data
	var tag_name: String = data.get("tag_name", "")
	_latest_release_url = data.get("html_url", "")

	if tag_name.is_empty():
		return

	var current_version: String = ProjectSettings.get_setting("application/config/version", "0.1.0")

	# Compare versions numerically
	if _is_newer_version(tag_name, current_version):
		var changelog: String = data.get("body", "A new version of the app is available!")
		# Truncate long changelogs for the popup
		if changelog.length() > 300:
			changelog = changelog.substr(0, 300) + "..."

		_update_dialog.dialog_text = (
			"A new version (%s) is available! (Current: %s)\n\nNotes:\n%s\n\nWould you like to open the download page?"
			% [tag_name, current_version, changelog]
		)
		_update_dialog.popup_centered(Vector2i(260, 120))


## Returns true if remote_version is strictly newer than current_version
func _is_newer_version(remote: String, current: String) -> bool:
	var clean_remote: String = remote.trim_prefix("v").split("-")[0]
	var clean_current: String = current.trim_prefix("v").split("-")[0]

	var remote_parts: PackedStringArray = clean_remote.split(".")
	var current_parts: PackedStringArray = clean_current.split(".")

	var max_len: int = max(remote_parts.size(), current_parts.size())

	for i in range(max_len):
		var r_num: int = int(remote_parts[i]) if i < remote_parts.size() else 0
		var c_num: int = int(current_parts[i]) if i < current_parts.size() else 0

		if r_num > c_num:
			return true
		elif r_num < c_num:
			return false

	return false


func _on_update_confirmed() -> void:
	if not _latest_release_url.is_empty():
		OS.shell_open(_latest_release_url)
