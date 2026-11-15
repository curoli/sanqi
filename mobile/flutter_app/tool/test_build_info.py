"""Check the build wrapper without requiring an Android/iOS SDK."""

import datetime
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class BuildInfoTest(unittest.TestCase):
    def test_metadata_arguments_working_directory_and_exit_status(self):
        app = Path(__file__).resolve().parent.parent
        commit = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=app, text=True
        ).strip()
        if subprocess.run(["git", "diff", "--quiet", "HEAD", "--"], cwd=app).returncode:
            commit += "-dirty"
        with tempfile.TemporaryDirectory() as temporary:
            fake_flutter = Path(temporary) / "flutter"
            fake_flutter.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, sys\n"
                "print(json.dumps({'cwd': os.getcwd(), 'args': sys.argv[1:]}))\n"
                "sys.exit(int(os.environ['SANQI_TEST_EXIT']))\n"
            )
            fake_flutter.chmod(0o755)
            for exit_code in [0, 23]:
                with self.subTest(exit_code=exit_code):
                    before = datetime.datetime.now(datetime.timezone.utc)
                    result = subprocess.run(
                        [str(app / "tool/flutter_with_build_info.sh"), "build", "apk",
                         "--debug", "--dart-define=OTHER=value with spaces"],
                        cwd=temporary,
                        env={**os.environ, "PATH": temporary + os.pathsep + os.environ["PATH"],
                             "SANQI_TEST_EXIT": str(exit_code)},
                        capture_output=True, text=True,
                    )
                    after = datetime.datetime.now(datetime.timezone.utc)
                    self.assertEqual(result.returncode, exit_code, result.stderr)
                    captured = json.loads(result.stdout)
                    self.assertEqual(captured["cwd"], str(app))
                    self.assertEqual(captured["args"][:4], [
                        "build", "apk", "--debug", "--dart-define=OTHER=value with spaces"
                    ])
                    self.assertEqual(captured["args"][-1], "--dart-define=SANQI_GIT_COMMIT=" + commit)
                    date = captured["args"][-2].removeprefix("--dart-define=SANQI_BUILD_DATE=")
                    built = datetime.datetime.strptime(date, "%Y-%m-%dT%H:%M:%SZ").replace(
                        tzinfo=datetime.timezone.utc
                    )
                    self.assertLessEqual(before.replace(microsecond=0), built)
                    self.assertLessEqual(built, after)


if __name__ == "__main__":
    unittest.main()
