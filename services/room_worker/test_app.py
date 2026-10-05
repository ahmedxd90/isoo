import json
import unittest

from app import inspect_media, normalize_event


class RoomWorkerTests(unittest.TestCase):
    def test_normalize_event_preserves_room_and_id(self):
        result = normalize_event({"id": "gift-1", "type": "gift", "room_id": "room-1"})
        self.assertEqual(result["event_id"], "gift-1")
        self.assertEqual(result["event_type"], "gift")
        self.assertEqual(result["room_id"], "room-1")
        json.dumps(result)

    def test_inspect_missing_media_is_safe(self):
        result = inspect_media("/tmp/saki-file-that-does-not-exist.mp4")
        self.assertFalse(result["exists"])
        self.assertEqual(result["type"], "mp4")
        self.assertFalse(result["supported"])

    def test_inspect_rejects_unknown_extension(self):
        result = inspect_media("/tmp/file.exe")
        self.assertFalse(result["supported"])
        self.assertEqual(result["reason"], "unsupported_extension")


if __name__ == "__main__":
    unittest.main()
