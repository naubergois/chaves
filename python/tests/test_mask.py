import unittest

from chaves.mask import is_placeholder, is_storable_name, mask_secret
from chaves.catalog import catalog_entry


class MaskTests(unittest.TestCase):
    def test_mask_hides_middle(self):
        self.assertEqual(mask_secret("sk-abcdefghijklmnop"), "sk-a…mnop")

    def test_mask_short_is_dots(self):
        self.assertIn("•", mask_secret("abcd"))

    def test_placeholder(self):
        self.assertTrue(is_placeholder(""))
        self.assertTrue(is_placeholder("your_key"))
        self.assertFalse(is_placeholder("sk-live-real"))

    def test_storable_name(self):
        self.assertTrue(is_storable_name("OPENAI_API_KEY"))
        self.assertFalse(is_storable_name("openai-api-key"))
        self.assertFalse(is_storable_name("2BAD"))

    def test_unknown_catalog_falls_to_env(self):
        row = catalog_entry("BRAND_NEW_TOKEN")
        self.assertEqual(row["category"], "env")
        self.assertEqual(row["name"], "BRAND_NEW_TOKEN")


if __name__ == "__main__":
    unittest.main()
