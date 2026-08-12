import os
from unittest import TestCase
from unittest.mock import patch

from config.settings.base import env_list_with_extras


class EnvListWithExtrasTests(TestCase):
    def test_appends_local_hosts_without_duplicates(self):
        with patch.dict(
            os.environ,
            {"DJANGO_ALLOWED_HOSTS": "eco.example.com,localhost"},
            clear=False,
        ):
            hosts = env_list_with_extras(
                "DJANGO_ALLOWED_HOSTS",
                "127.0.0.1,localhost",
                extras=("127.0.0.1", "localhost", "0.0.0.0"),
            )

        self.assertEqual(
            hosts,
            ["eco.example.com", "localhost", "127.0.0.1", "0.0.0.0"],
        )
