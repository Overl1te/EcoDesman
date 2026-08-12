from django.test import SimpleTestCase

from config.settings.base import host_variants, origin_variants


class SettingsHelperTests(SimpleTestCase):
    def test_host_variants_include_punycode_for_idn(self):
        self.assertEqual(
            host_variants("api.эковыхухоль.рф"),
            ["api.эковыхухоль.рф", "api.xn--b1apekb3anb5cpb.xn--p1ai"],
        )

    def test_origin_variants_include_punycode_for_idn(self):
        self.assertEqual(
            origin_variants("http://эковыхухоль.рф"),
            ["http://эковыхухоль.рф", "http://xn--b1apekb3anb5cpb.xn--p1ai"],
        )
