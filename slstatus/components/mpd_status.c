#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Component: MPD Status */
const char *
mpd_status(const char *unused)
{
    FILE *fp;
    char *output = NULL;
    char buffer[128];

    /* تشغيل أمر mpc للحصول على حالة التشغيل والعنوان والفنان */
    fp = popen("mpc -f '[%artist% - ][%title%][ [%state%]]'", "r");
    if (fp == NULL) {
        return "⏹ Error"; // عرض رسالة إذا فشل الأمر
    }

    if (fgets(buffer, sizeof(buffer), fp)) {
        buffer[strcspn(buffer, "\n")] = '\0'; // حذف السطر الجديد

        /* التحقق مما إذا كان الإخراج فارغًا أو يحتوي على رسائل غير مرغوبة */
        if (strlen(buffer) == 0 || strstr(buffer, "volume:") || strstr(buffer, "ERROR")) {
            output = "⏹ No Music"; // عرض رسالة إذا لم يكن هناك موسيقى
        } else {
            /* تحليل حالة التشغيل */
            if (strstr(buffer, "[playing]")) {
                asprintf(&output, "▶ %s", buffer);
            } else if (strstr(buffer, "[paused]")) {
                asprintf(&output, "⏸ %s", buffer);
            } else if (strstr(buffer, "[stopped]")) {
                asprintf(&output, "⏹ %s", buffer);
            } else {
                asprintf(&output, " %s", buffer);
            }
        }
    } else {
        output = "⏹ Error"; // عرض رسالة إذا فشل قراءة الإخراج
    }

    pclose(fp); // إغلاق الأمر
    return output ? output : "⏹ No Music"; // إرجاع النص النهائي
}
