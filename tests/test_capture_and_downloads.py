"""Regression checks for window capture lifecycle and corrupt downloads."""
import hashlib
import json
import os
import signal
import time
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = (ROOT / 'application/scripts/install_barefront.sh').read_text()


class CaptureTests(unittest.TestCase):
    def run_capture(self, directory, mode="success", *overrides):
        directory = Path(directory)
        ffmpeg = directory / "ffmpeg"
        ffmpeg.write_text("""#!/usr/bin/env python3
import json, os, pathlib, sys, time
pathlib.Path(os.environ['CAPTURE_ARGS']).write_text(json.dumps(sys.argv[1:]))
if os.environ['CAPTURE_MODE'] == 'failure':
    sys.exit(1)
if os.environ['CAPTURE_MODE'] == 'wait':
    pathlib.Path(os.environ['TEST_ENCODER_PID']).write_text(str(os.getpid()))
    time.sleep(60)
pathlib.Path(sys.argv[-1]).write_bytes(b'new recording')
""")
        ffmpeg.chmod(0o755)
        output = directory / "preview.mp4"
        output.write_bytes(b"existing preview")
        arguments = [str(output), "941", "1023", "13", "21", "901", "975",
                     "220", "238", "12345"]
        for index, value in overrides:
            arguments[index] = value
        env = dict(os.environ, PATH=str(directory) + os.pathsep + os.environ['PATH'],
                   DISPLAY=":test", CAPTURE_ARGS=str(directory / 'args.json'),
                   TEST_ENCODER_PID=str(directory / 'pid'), CAPTURE_MODE=mode)
        return subprocess.Popen(['bash', str(ROOT / 'application/scripts/capture_gamescope_video.sh'),
                                 *arguments], env=env, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE)

    def test_captures_exact_window_and_crop_without_pipewire(self):
        with tempfile.TemporaryDirectory() as directory:
            process = self.run_capture(directory)
            process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0)
            args = json.loads((Path(directory) / 'args.json').read_text())
            self.assertEqual(args[args.index('-window_id') + 1], '12345')
            self.assertEqual(args[args.index('-video_size') + 1], '941x1023')
            self.assertEqual(args[args.index('-i') + 1], ':test')
            self.assertIn('crop=901:975:13:21', args[args.index('-vf') + 1])
            self.assertEqual((Path(directory) / 'preview.mp4').read_bytes(), b'new recording')
            self.assertFalse(list(Path(directory).glob('*.part.*')))

    def test_failed_capture_preserves_previous_preview(self):
        with tempfile.TemporaryDirectory() as directory:
            process = self.run_capture(directory, 'failure')
            process.communicate(timeout=5)
            self.assertNotEqual(process.returncode, 0)
            self.assertEqual((Path(directory) / 'preview.mp4').read_bytes(), b'existing preview')
            self.assertFalse(list(Path(directory).glob('*.part.*')))

    def test_exit_stops_encoder_and_preserves_previous_preview(self):
        with tempfile.TemporaryDirectory() as directory:
            process = self.run_capture(directory, 'wait')
            try:
                deadline = time.monotonic() + 5
                pid_file = Path(directory) / 'pid'
                while not pid_file.exists() and time.monotonic() < deadline:
                    time.sleep(0.02)
                self.assertTrue(pid_file.exists())
                encoder_pid = int(pid_file.read_text())
                process.send_signal(signal.SIGTERM)
                process.communicate(timeout=5)
                self.assertEqual(process.returncode, 143)
                with self.assertRaises(ProcessLookupError):
                    os.kill(encoder_pid, 0)
                self.assertEqual((Path(directory) / 'preview.mp4').read_bytes(), b'existing preview')
                self.assertFalse(list(Path(directory).glob('*.part.*')))
            finally:
                if process.poll() is None:
                    process.kill()
                    process.communicate()

    def test_invalid_crop_rejected_before_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            process = self.run_capture(directory, 'success', (5, '941'))
            process.communicate(timeout=5)
            self.assertEqual(process.returncode, 2)
            self.assertFalse((Path(directory) / 'args.json').exists())


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
