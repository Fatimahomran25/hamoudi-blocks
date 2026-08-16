# 🧊 بلوك حمودي (Hamoudi Blocks)

لعبة تعليمية للحروف والأرقام (عربي/إنجليزي) لطفل عمره 4 سنوات، مبنية
بـ Flutter. هذا الريبو أنهى **Milestone 1** (هيكل التطبيق)، **Milestone
2** (عالم اللعب ثلاثي الأبعاد الحقيقي بـ Three.js داخل WebView محلي)،
و**Milestone 3** (الصوت المسجّل مسبقاً بصوت سعودي طبيعي عبر Azure Neural
TTS) — مزامنة Firebase لسا ما اتضافت (تفاصيل كل مرحلة بـ
[NEXT_STEPS.md](NEXT_STEPS.md)).

## تشغيل المشروع

```bash
flutter pub get
flutter run          # يشغّله على أي جهاز/محاكي متصل
flutter test         # اختبار الدخان
flutter analyze      # فحص ثابت — يفترض يطلع "No issues found!"
```

## بناء وتثبيت مباشر على جهاز (بدون متجر)

```bash
# أندرويد — يعطيك APK تنقلينه للجوال وتثبتينه مباشرة
flutter build apk --release

# آيفون — يحتاج ماك + Xcode + كيبل + Apple ID عادي (مجاني)
flutter build ios --release
# بعدها افتحي ios/Runner.xcworkspace بـ Xcode ونفّذي Run على الجهاز الموصول.
```

## خريطة الشاشات الحالية

```
SignInScreen (حساب الوالد — مرة وحدة)
  → AddChildScreen (اسم الطفل)
    → AvatarSelectScreen (اختيار الشخصية)
      → GameLoginScreen (بروفايل الطفل، الدخول التلقائي بالمرات الجاية)
        → MainMenuScreen (🔤 الحروف / 🔢 الأرقام)
          → LanguageSelectScreen (🇸🇦 / 🇬🇧)
            → LevelsScreen (شبكة المستويات + النجوم + القفل)
              → GameScreen (WebView — عالم Three.js ثلاثي الأبعاد الحقيقي)
                → LevelResultScreen (فوز 🎉 / حاول مرة ثانية 💪)
```

## بنية الكود

```
lib/
  app.dart                 # MaterialApp + AuthGate (يقرر أول شاشة حسب الجلسة)
  theme/app_theme.dart      # الألوان + NeoBox (حدود سوداء + ظل صندوقي)
  models/                   # ChildProfile, AvatarOption, ContentItem/Group
  data/content_repository.dart  # كل الحروف/الأرقام (74 عنصر) + تقسيمها لمستويات
  services/
    auth_service.dart       # بوابة حساب الوالد (محلي الآن، Firebase لاحقاً)
    profile_service.dart    # بروفايلات الأطفال + التقدم (محلي الآن)
    audio_service.dart      # يشغّل مقاطع assets/audio/ الحقيقية (Azure Neural TTS، صوت سعودي)
  screens/
    onboarding/  home/  game/  settings/
    game/game_screen.dart    # WebView محلي لعالم Three.js + جسر GameChannel
  widgets/
    big_button.dart  star_row.dart (StarRow + HeartRow)  blocky_avatar.dart

assets/game3d/              # عالم اللعب ثلاثي الأبعاد (Three.js، بدون إنترنت)
  index.html  style.css  game.js
  vendor/three.module.js    # مكتبة Three.js مُضمَّنة محلياً (لا CDN)
  fonts/*.woff2              # خط Baloo Bhaijaan 2 مُضمَّن محلياً

assets/audio/                # صوت سعودي طبيعي مسجّل مسبقاً (Azure Neural TTS، فصحى)
  content/{ar|en}_{letter|number}_N.wav       # "قُل: أ... مثل أسد!" (74 ملف)
  content_found/{ar|en}_{letter|number}_N.wav # تكرار 3 مرات عند النجاح (74 ملف)
  phrases/*.wav                                # ترحيب/تشجيع/تلميح/خطأ/فوز (12 ملف)
```

كل خدمة (`AuthService`, `ProfileService`, `AudioService`) مصمّمة بحيث
الشاشات تتعامل مع واجهتها العامة فقط — استبدال الجسم الداخلي لاحقاً
(Firebase، ملفات صوت حقيقية) ما يحتاج تعديل أي شاشة.

## عالم اللعب ثلاثي الأبعاد (`GameScreen`)

`GameScreen` (بـ `lib/screens/game/game_screen.dart`) يعرض
`assets/game3d/index.html` عبر `webview_flutter` محلياً وبدون إنترنت.
التواصل بالاتجاهين عبر JavaScript Channel واحد اسمه `GameChannel`:

- **الصفحة → Flutter**: `{type:'ready'}` عند التهيئة، `{type:'audio',
  event, ...}` لكل حدث صوتي (يُموَّل لميثود بـ `AudioService`)،
  `{type:'result', outcome:'win'|'retry', ...}` عند انتهاء المستوى،
  `{type:'exit'}` عند ضغط ✖️.
- **Flutter → الصفحة**: `window.HamoudiGame.init(config)` بعد استقبال
  `ready` — يحمل اسم الطفل، ألوان `AvatarOption` المختار، وعناصر
  المستوى الأربعة من `ContentRepository`.

راجعي التعليقات أعلى `assets/game3d/game.js` لتفاصيل كل رسالة ولمنطق
اللعب الكامل (القلوب، التلميح، الاحتفال، الحركات).
