from ultralytics import YOLO
import supervision as sv
import cv2
import torch
from datetime import datetime
import psycopg2
from deep_sort_realtime.deepsort_tracker import DeepSort
import numpy as np


# ---------------------- Veritabanı Bağlantısı ----------------------
conn = psycopg2.connect(
    host="localhost", 
    database="donem_sonu", 
    port = 5433,
    user="postgres", 
    password="220902"
)
conn.autocommit = True
cur = conn.cursor()

# ---------------------- Model ve Sınıf Bilgileri ----------------------
vehicle_classes = {
    0: "car", 
    1: "threewheel", 
    2: "bus", 
    3: "truck", 
    4: "motorbike", 
    5: "van"
}
allowed_vehicle_classes = {0, 1, 2, 3, 4, 5}

class_names = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
    'K', 'L', 'M', 'N', 'O', 'P', 'R', 'S', 'T', 'U',
    'V', 'Y', 'Z'
]

# ---------------------- Cihaz Seçimi ----------------------
device = "mps" if torch.cuda.is_available() else "cpu"
print(f"Using device: {device}")

# ---------------------- Modellerin Yüklenmesi ----------------------

vehicle_model = YOLO("//Users//tunahanbg//Code//vscode_files//db_donem_sonu//final_sql_model_detect//models//vehicle_detect_v1.pt").to(device)
plate_model = YOLO("//Users//tunahanbg//Code//vscode_files//db_donem_sonu//final_sql_model_detect//models//plate_detection.pt").to(device)
char_model = YOLO("//Users//tunahanbg//Code//vscode_files//db_donem_sonu//final_sql_model_detect//models//plate_number_det.pt").to(device)

# ---------------------- Video Kaynağı ----------------------
video_capture = cv2.VideoCapture("//Users//tunahanbg//Code//vscode_files//db_donem_sonu//final_sql_model_detect//car_det_test_v2.mp4")

frame_width = int(video_capture.get(cv2.CAP_PROP_FRAME_WIDTH))
frame_height = int(video_capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
fps = int(video_capture.get(cv2.CAP_PROP_FPS))

output_video = cv2.VideoWriter(
    "output_video.mp4",
    cv2.VideoWriter_fourcc(*'mp4v'),
    fps,
    (frame_width, frame_height)
)

# ---------------------- Çizgi Koordinatları ----------------------
line_y = frame_height // 2 + 400
line_start = (0, line_y)
line_end = (frame_width, line_y)

crossed_count = 0
crossed_objects = set()  # Çizgiyi geçmiş track_id'leri depolar

# ---------------------- DeepSort Trackers ----------------------
tracker_vehicles = DeepSort(
    max_age=15,
    nms_max_overlap=0.5,
    embedder="mobilenet",
    half=True,
    today=datetime.now(),
    n_init=5,
    max_iou_distance=0.5,
    max_cosine_distance=0.1
)

tracker_plates = DeepSort(
    max_age=15,
    nms_max_overlap=0.5,
    embedder="mobilenet",
    half=True,
    today=datetime.now(),
    n_init=5,
    max_iou_distance=0.5,
    max_cosine_distance=0.1
)

# Araç ve plaka eşleştirmesi için sözlük
# vehicle_plates[vehicle_track_id] = plate_number
vehicle_plates = {}

while True:
    ret, frame = video_capture.read()
    if not ret:
        break

    # ---------------------- Araç Tespiti ----------------------
    vehicle_results = vehicle_model(frame)
    vehicle_detections = sv.Detections(
        xyxy=vehicle_results[0].boxes.xyxy.cpu().numpy(),
        confidence=vehicle_results[0].boxes.conf.cpu().numpy(),
        class_id=vehicle_results[0].boxes.cls.cpu().numpy().astype(int)
    )

    # Araçları DeepSort'a hazırlama
    vehicle_detections_for_tracker = []
    for bbox, conf, class_id in zip(vehicle_detections.xyxy, vehicle_detections.confidence, vehicle_detections.class_id):
        if class_id in allowed_vehicle_classes:
            left, top, right, bottom = map(float, bbox)
            w = right - left
            h = bottom - top
            vehicle_detections_for_tracker.append(([left, top, w, h], conf, class_id))

    # ---------------------- Plaka Tespiti ----------------------
    plate_results = plate_model(frame)
    plate_detections = sv.Detections(
        xyxy=plate_results[0].boxes.xyxy.cpu().numpy(),
        confidence=plate_results[0].boxes.conf.cpu().numpy(),
        class_id=plate_results[0].boxes.cls.cpu().numpy().astype(int)
    )
    # Plakaları DeepSort'a hazırlama
    plate_detections_for_tracker = []
    for bbox, conf, class_id in zip(plate_detections.xyxy, plate_detections.confidence, plate_detections.class_id):
        left, top, right, bottom = map(float, bbox)
        w = right - left
        h = bottom - top
        plate_detections_for_tracker.append(([left, top, w, h], conf, class_id))

    # ---------------------- Takip İşlemleri ----------------------
    tracked_vehicles = tracker_vehicles.update_tracks(vehicle_detections_for_tracker, frame=frame)
    tracked_plates = tracker_plates.update_tracks(plate_detections_for_tracker, frame=frame)

    # Tracked araç bilgilerini sakla (id, bbox, class)
    current_vehicles = {}
    for track in tracked_vehicles:
        if not track.is_confirmed() or track.time_since_update > 1:
            continue
        track_id = track.track_id
        x1, y1, x2, y2 = map(int, track.to_ltrb())
        class_id = track.det_class
        vehicle_label = vehicle_classes.get(class_id, 'Unknown')
        current_vehicles[track_id] = {
            'bbox': (x1, y1, x2, y2),
            'class_id': class_id,
            'type_name': vehicle_label
        }

        # Araç çizim
        cv2.rectangle(frame, (x1, y1), (x2, y2), (255, 0, 0), 2)
        cv2.putText(frame, f"{vehicle_label} ID: {track_id}", (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 0, 0), 2)

    # Tracked plakalar için karakter tespiti yap ve plakayı çiz
    current_plates = {}
    for track in tracked_plates:
        if not track.is_confirmed() or track.time_since_update > 1:
            continue
        p_track_id = track.track_id
        px1, py1, px2, py2 = map(int, track.to_ltrb())

        plate_crop = frame[py1:py2, px1:px2]
        # Karakter tespiti
        char_results = char_model(plate_crop)
        char_boxes = []
        for char_result in char_results:
            for char_box in char_result.boxes:
                char_id = int(char_box.cls)
                char_name = class_names[char_id]
                # Her karakterin sol üst x koordinatını al
                x_min = float(char_box.xyxy[0][0])
                char_boxes.append((x_min, char_name))

        # Karakterleri x_min değerine göre sırala (sol üstten sağa doğru)
        char_boxes.sort(key=lambda x: x[0])
        plate_number = ''.join([c[1] for c in char_boxes])

        current_plates[p_track_id] = {
            'bbox': (px1, py1, px2, py2),
            'plate_number': plate_number
        }

        # Plaka çerçevesi ve yazısı
        cv2.rectangle(frame, (px1, py1), (px2, py2), (0, 255, 255), 2)
        cv2.putText(frame, f"Plate: {plate_number}", (px1, py1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0,255,255), 2)

    # ---------------------- Araç ve Plaka Eşleştirme ----------------------
    # Her plakayı, iç içe ya da kesişim yoluyla bir araca ait olarak bağla
    # IoU hesabı yaparak plakayı araca match ediyoruz.
    for v_id, v_info in current_vehicles.items():
        vx1, vy1, vx2, vy2 = v_info['bbox']
        vehicle_box = np.array([vx1, vy1, vx2, vy2], dtype=np.float32)

        best_iou = 0.0
        best_plate_num = None
        for p_id, p_info in current_plates.items():
            px1, py1, px2, py2 = p_info['bbox']
            plate_box = np.array([px1, py1, px2, py2], dtype=np.float32)

            # IoU hesabı
            inter_x1 = max(vx1, px1)
            inter_y1 = max(vy1, py1)
            inter_x2 = min(vx2, px2)
            inter_y2 = min(vy2, py2)

            if inter_x2 < inter_x1 or inter_y2 < inter_y1:
                iou = 0.0
            else:
                inter_area = (inter_x2 - inter_x1) * (inter_y2 - inter_y1)
                v_area = (vx2 - vx1) * (vy2 - vy1)
                p_area = (px2 - px1) * (py2 - py1)
                iou = inter_area / float(v_area + p_area - inter_area)

            # Plaka numarası varsa ve iou daha iyi ise güncelle
            if iou > best_iou and p_info['plate_number']:
                best_iou = iou
                best_plate_num = p_info['plate_number']

        # Eğer uygun IoU bulunduysa, bu plakayı bu araca ata
        if best_plate_num:
            # Eğer daha önce bu araca plaka atandıysa, sadece daha uzun olanı kabul et
            if v_id in vehicle_plates:
                if len(best_plate_num) > len(vehicle_plates[v_id]):
                    vehicle_plates[v_id] = best_plate_num
            else:
                vehicle_plates[v_id] = best_plate_num

    # ---------------------- Çizgi Geçiş Kontrolü ----------------------
    for v_id, v_info in current_vehicles.items():
        vx1, vy1, vx2, vy2 = v_info['bbox']
        center_x, center_y = (vx1 + vx2) // 2, (vy1 + vy2) // 2

        if (line_y - 10 <= center_y <= line_y + 10) and (v_id not in crossed_objects):
            crossed_count += 1
            crossed_objects.add(v_id)

            # Araç çizgiyi geçerken plaka var mı kontrol et
            plate_number = vehicle_plates.get(v_id, None)
            if plate_number:
                # Araç tipini al
                vehicle_type_name = v_info['type_name']

                # 1. Vehicle_Type tablosunda type_name kontrolü
                cur.execute("SELECT type_id FROM vehicle_type WHERE type_name = %s;", (vehicle_type_name,))
                type_id_result = cur.fetchone()
                if type_id_result is None:
                    # Yoksa yeni kayıt ekle (ör: price = 0.00)
                    cur.execute("INSERT INTO vehicle_type (type_name, price) VALUES (%s, 0.00) RETURNING type_id;", (vehicle_type_name,))
                    type_id = cur.fetchone()[0]
                else:
                    type_id = type_id_result[0]

                # 2. Vehicles tablosuna plakayı ekle (varsa geç, yoksa ekle)
                insert_vehicles_query = """
                    INSERT INTO vehicles (plate_number, type_id, is_detected) 
                    VALUES (%s, %s, TRUE)
                    ON CONFLICT (plate_number) DO NOTHING;
                """
                cur.execute(insert_vehicles_query, (plate_number, type_id))

                # 3. Parking_Records tablosuna giriş kaydı ekle
                entry_time = datetime.now()
                insert_parking_query = """
                    INSERT INTO parking_records (plate_number, entry_time, cost, user_id, session_time) 
                    VALUES (%s, %s, NULL, %s, NULL);
                """
                cur.execute(insert_parking_query, (plate_number, entry_time, 0))

                # Veritabanına eklenen aracın bilgilerini terminale yazdır
                print(f"Veritabanına eklendi: Plaka = {plate_number}, Araç Tipi = {vehicle_type_name}, Giriş Zamanı = {entry_time}")
            # Plaka yoksa bu araç eklenmez.

    # Çizgi ve bilgileri ekranda göster
    cv2.line(frame, line_start, line_end, (0, 255, 0), 2)
    cv2.putText(frame, f"Crossed: {crossed_count}", (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)

    output_video.write(frame)
    cv2.imshow("Video", frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

video_capture.release()
output_video.release()
cv2.destroyAllWindows()

cur.close()
conn.close()

