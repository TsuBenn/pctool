import sys
import numpy as np
import cv2
import json

def order_points(pts):
    pts = pts.reshape((4, 2))
    rect = np.zeros((4, 2), dtype="float32")
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]
    rect[2] = pts[np.argmax(s)]
    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]
    rect[3] = pts[np.argmax(diff)]
    return rect.reshape((4, 1, 2))

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "no image path provided"}))
        sys.exit(1)

    img_path = sys.argv[1]
    img = cv2.imread(img_path)

    if img is None:
        print(json.dumps({"error": f"could not read image: {img_path}"}))
        sys.exit(1)

    height, width, channel = img.shape

    imgGray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    imgBlur = cv2.GaussianBlur(imgGray, (5, 5), 5)
    imgThres = cv2.Canny(imgBlur, 0, 60)
    kernel = np.ones((5, 5))
    imgDial = cv2.dilate(imgThres, kernel, iterations=2)
    imgThres = cv2.erode(imgDial, kernel, iterations=1)

    contours, _ = cv2.findContours(imgThres, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    biggest = None
    max_area = 0
    for c in contours:
        area = cv2.contourArea(c)
        if area > 5000:
            peri = cv2.arcLength(c, True)
            approx = cv2.approxPolyDP(c, 0.02 * peri, True)
            if area > max_area and len(approx) == 4:
                biggest = approx
                max_area = area

    if biggest is None:
        print(json.dumps({"error": "no quadrilateral contour found"}))
        sys.exit(1)

    points = (order_points(biggest)/np.array([width, height])).reshape(4, 2).tolist()
    result = {
        "top_left": points[0],
        "top_right": points[1],
        "bottom_right": points[2],
        "bottom_left": points[3],
    }
    print(json.dumps(result))

if __name__ == "__main__":
    main()
