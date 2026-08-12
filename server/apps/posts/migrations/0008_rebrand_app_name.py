from django.db import migrations


def apply_rebrand(apps, schema_editor):
    User = apps.get_model("users", "User")
    User.objects.filter(display_name="EcoNizhny Admin").update(
        display_name="ЭкоВыхухоль Admin",
    )


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("posts", "0007_postview"),
    ]

    operations = [
        migrations.RunPython(apply_rebrand, noop),
    ]
