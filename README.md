# مشروع ربط مودل EfficientNetV2-S بتطبيق Flutter عبر FastAPI

هذا المشروع يقدم حلاً كاملاً لربط مودل تصنيف صور (Image Classification Model) مبني على PyTorch/EfficientNetV2-S بتطبيق موبايل Flutter، وذلك باستخدام واجهة برمجية (API) مبنية على إطار عمل **FastAPI** في Python.

## محتويات المشروع

يتكون المشروع من جزأين رئيسيين:

1.  **FastAPI Backend (الخادم):** يستقبل الصور، يجري عملية الـ Inference، ويعيد النتيجة.
2.  **Flutter Frontend (العميل):** تطبيق موبايل يسمح للمستخدم باختيار صورة وإرسالها إلى الخادم.

---

## 1. FastAPI Backend (Python)

### المتطلبات

يجب تثبيت المكتبات التالية في بيئة Python الخاصة بك:

\`\`\`bash
pip install torch torchvision fastapi uvicorn python-multipart pillow
\`\`\`

### ملفات الكود

| الملف | الوصف |
| :--- | :--- |
| \`effv2s_fold5.pt\` | **ملف المودل الخاص بكم.** يجب وضعه في نفس مجلد ملفات Python. |
| \`model_inference.py\` | يحتوي على منطق تحميل المودل، تعريف بنية المودل (\`create_model\`)، وتحويل الصورة (\`ResizePadToSquare\` و \`get_inference_transform\`)، وتشغيل الـ Inference (\`ImagePredictor\`). |
| \`main.py\` | يحتوي على تطبيق FastAPI. يقوم بتحميل المودل مرة واحدة عند بدء التشغيل، ويحتوي على مسار \`/predict\` الذي يستقبل الصورة. |

### كيفية التشغيل

1.  **تأكد** من أن ملف المودل \`effv2s_fold5.pt\` موجود في نفس المجلد مع \`main.py\` و \`model_inference.py\`.
2.  قم بتشغيل الخادم باستخدام \`uvicorn\`:

    \`\`\`bash
    uvicorn main:app --host 0.0.0.0 --port 8000
    \`\`\`

3.  سيصبح الـ API متاحاً على العنوان \`http://0.0.0.0:8000\`.

### مسار الـ API

| المسار | النوع | الوصف |
| :--- | :--- | :--- |
| \`/predict\` | POST | المسار الرئيسي. يستقبل ملف صورة (\`multipart/form-data\`) ويعيد نتيجة التصنيف بصيغة JSON. |
| \`/\` | GET | فحص حالة الخادم (Health Check). |

#### مثال على استجابة \`/predict\` (JSON)

\`\`\`json
{
  "predicted_label": "Real",
  "predicted_index": 1,
  "probabilities": {
    "Fake": 0.05,
    "Real": 0.95
  }
}
\`\`\`

---

## 2. Flutter Frontend (العميل)

### المتطلبات

1.  تطبيق Flutter جاهز للتشغيل.
2.  إضافة المكتبات المطلوبة في ملف \`pubspec.yaml\`:

    \`\`\`yaml
    dependencies:
      image_picker: ^1.1.2
      http: ^1.2.1
    \`\`\`

    ثم قم بتشغيل \`flutter pub get\`.

### ملفات الكود

| الملف | الوصف |
| :--- | :--- |
| \`flutter_app/pubspec.yaml\` | ملف تعريف المكتبات. |
| \`flutter_app/lib/main.dart\` | يحتوي على واجهة المستخدم ومنطق اختيار الصورة وإرسالها إلى الـ API عبر \`http.MultipartRequest\`. |

### ملاحظة هامة حول الاتصال بالـ API

في ملف \`main.dart\`، تم تعيين عنوان الـ API كالتالي:

\`\`\`dart
const String apiBaseUrl = 'http://10.0.2.2:8000'; 
\`\`\`

*   **إذا كنت تستخدم محاكي Android:** يجب استخدام \`10.0.2.2\` للوصول إلى \`localhost\` على جهاز الكمبيوتر الخاص بك.
*   **إذا كنت تستخدم محاكي iOS أو جهاز حقيقي:** استخدم \`http://localhost:8000\` أو عنوان IP المحلي لجهاز الكمبيوتر الخاص بك (مثلاً \`http://192.168.1.5:8000\`).
*   **إذا كنت تستخدم خادم سحابي:** استبدل العنوان بعنوان IP العام للخادم.

### خطوات التشغيل في Flutter

1.  قم بتشغيل الـ API في الخلفية (الخطوة 2 من قسم FastAPI).
2.  افتح مشروع Flutter في بيئة التطوير الخاصة بك.
3.  قم بتشغيل التطبيق على محاكي أو جهاز حقيقي.
4.  اضغط على زر **"Select Image from Gallery"** لاختيار صورة.
5.  اضغط على زر **"Run Prediction"** لإرسال الصورة إلى الـ API وعرض النتيجة.

---

## 3. الكود المرفق

تم إنشاء الملفات التالية لكم:

*   \`main.py\`
*   \`model_inference.py\`
*   \`flutter_app/pubspec.yaml\`
*   \`flutter_app/lib/main.dart\`

يمكنكم استخدام هذه الملفات مباشرة في مشروعكم. بالتوفيق في مشروع التخرج!
