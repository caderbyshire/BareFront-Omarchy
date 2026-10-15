"""Regression checks for renamed PipeWire sources and corrupt downloads."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
RECORDER = (ROOT / 'application/scripts/capture_gamescope_video.sh').read_text()
INSTALLER = (ROOT / 'application/scripts/install_barefront.sh').read_text()
SCRIPTS = re.findall(r"python3 -c '\n(.*?)\n'", RECORDER, re.S)


def run_selector(script, objects, *args):
    return subprocess.run(['python3', '-c', script, *args], input=json.dumps(objects),
                          text=True, capture_output=True, check=True).stdout.strip()


def obj(number, **props):
    return {'id': number, 'info': {'props': props}}


class CaptureTests(unittest.TestCase):
    def test_private_and_standard_video_sources(self):
        for name in ('gamescope.bin', 'gamescope'):
            objects = [obj(1, **{'media.class': 'Audio/Source', 'node.name': name}),
                       obj(80, **{'media.class': 'Video/Source', 'node.name': name})]
            self.assertEqual(run_selector(SCRIPTS[0], objects), '80')

    def test_media_name_survives_another_executable_rename(self):
        objects = [obj(80, **{'media.class': 'Video/Source', 'media.name': 'gamescope',
                             'node.name': 'private-runtime'})]
        self.assertEqual(run_selector(SCRIPTS[0], objects), '80')

    def test_links_selected_node_not_unrelated_capture(self):
        objects = [obj(81, **{'node.name': 'BareFront-capture-123'}),
                   obj(84, **{'node.name': 'different-recorder'}),
                   obj(88, **{'port.direction': 'out', 'node.id': 80}),
                   obj(89, **{'port.direction': 'out', 'node.id': 999}),
                   obj(90, **{'port.direction': 'in', 'node.id': 81}),
                   obj(91, **{'port.direction': 'in', 'node.id': 84})]
        self.assertEqual(run_selector(SCRIPTS[1], objects, '80', 'BareFront-capture-123'), '88 90')
        self.assertEqual(run_selector(SCRIPTS[1], objects, '80', 'missing-client'), '')


class DownloadTests(unittest.TestCase):
    def test_checksum_rejects_altered_download(self):
        function = re.search(r'verify_archive_sha256\(\)\n\{.*?\n\}', INSTALLER, re.S)[0]
        data = b'fixed upstream archive bytes\x00\xff'
        expected = hashlib.sha256(data).hexdigest()
        with tempfile.TemporaryDirectory(prefix='barefront checksum ') as directory:
            archive = Path(directory) / 'download.tar.gz'
            archive.write_bytes(data)
            command = function + '\nverify_archive_sha256 "$1" "$2"'
            result = subprocess.run(['bash', '-c', command, 'test', str(archive), expected])
            self.assertEqual(result.returncode, 0)
            archive.write_bytes(data + b'changed')
            result = subprocess.run(['bash', '-c', command, 'test', str(archive), expected])
            self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
