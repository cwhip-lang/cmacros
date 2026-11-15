#!/usr/bin/env python3
"""The format target runs cwhip-format -i and skips the build directory."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


PROJECT = Path(__file__).resolve().parents[1]
CMAKE = sys.argv.pop(1) if len(sys.argv) > 1 else shutil.which("cmake")
SCRIPT = PROJECT / "cmake" / "format.cmake"


class FormatTargetTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cmacros format ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = dict(os.environ)
        self.env["PATH"] = "/usr/bin:/bin"
        for name in ("CWHIP_SDK", "Cwhip_DIR", "CMAKE_PREFIX_PATH",
                     "FORMAT_LOG"):
            self.env.pop(name, None)

    def write_tree(self, source):
        files = {
            "keep.cw": "keep\n",
            "build.cw": "not the build directory\n",
            "src/nested.cw": "nested\n",
            "src/build/nested.cw": "source directory named build\n",
            "build/skip.cw": "generated\n",
            "build/nested/skip.cw": "generated nested\n",
            "out/skip.cw": "binary dir\n",
            "out/nested/skip.cw": "binary dir nested\n",
            ".cwhip-format": "Language: Cwhip\n",
        }
        for relative, text in files.items():
            path = source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
        return files

    def install_tool(self, status=0):
        bindir = self.root / "bin"
        bindir.mkdir()
        tool = bindir / "cwhip-format"
        log = self.root / "format-log.json"
        tool.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, sys\n"
            "from pathlib import Path\n"
            "Path(os.environ['FORMAT_LOG']).write_text(json.dumps({\n"
            "    'argv': sys.argv, 'cwd': os.getcwd()}))\n"
            f"raise SystemExit({status})\n",
            encoding="utf-8")
        tool.chmod(0o755)
        self.env["PATH"] = str(bindir) + os.pathsep + self.env["PATH"]
        self.env["FORMAT_LOG"] = str(log)
        return tool, log

    def run_script(self, source, binary):
        return subprocess.run(
            [CMAKE, f"-DCMACROS_SOURCE_DIR={source}",
             f"-DCMACROS_BINARY_DIR={binary}", "-P", str(SCRIPT)],
            cwd=source, env=self.env, capture_output=True, text=True)

    def test_missing_tool_fails_and_names_cwhip_format(self):
        source = self.root / "tree with spaces"
        self.write_tree(source)
        result = self.run_script(source, source / "out")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("cwhip-format is not available",
                      result.stdout + result.stderr)
        self.assertFalse((self.root / "format-log.json").exists())
        self.assertEqual((source / "keep.cw").read_text(encoding="utf-8"),
                         "keep\n")

    def test_runs_in_place_from_the_source_root_and_skips_build_dirs(self):
        source = self.root / "tree with spaces"
        originals = self.write_tree(source)
        tool, log = self.install_tool()
        result = self.run_script(source, source / "out")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        recorded = json.loads(log.read_text(encoding="utf-8"))
        self.assertEqual(Path(recorded["argv"][0]).resolve(), tool.resolve())
        self.assertEqual(recorded["argv"][1], "-i")
        formatted = {Path(path).resolve() for path in recorded["argv"][2:]}
        expected = {
            (source / "keep.cw").resolve(),
            (source / "build.cw").resolve(),
            (source / "src/nested.cw").resolve(),
            (source / "src/build/nested.cw").resolve(),
        }
        self.assertEqual(formatted, expected)
        self.assertEqual(Path(recorded["cwd"]).resolve(), source.resolve())
        for relative, text in originals.items():
            self.assertEqual((source / relative).read_text(encoding="utf-8"),
                             text)

    def test_in_source_binary_dir_still_formats_sources(self):
        source = self.root / "in source"
        self.write_tree(source)
        self.install_tool()
        result = self.run_script(source, source)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        recorded = json.loads(
            (self.root / "format-log.json").read_text(encoding="utf-8"))
        formatted = {Path(path).resolve() for path in recorded["argv"][2:]}
        self.assertIn((source / "keep.cw").resolve(), formatted)
        self.assertNotIn((source / "build/skip.cw").resolve(), formatted)
        self.assertIn((source / "out/skip.cw").resolve(), formatted)

    def test_separate_build_directory_is_skipped_when_named_build(self):
        source = self.root / "checkout"
        self.write_tree(source)
        self.install_tool()
        result = self.run_script(source, self.root / "other-build")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        recorded = json.loads(
            (self.root / "format-log.json").read_text(encoding="utf-8"))
        formatted = {Path(path).resolve() for path in recorded["argv"][2:]}
        self.assertNotIn((source / "build/skip.cw").resolve(), formatted)
        self.assertIn((source / "out/skip.cw").resolve(), formatted)

    def test_tool_failure_fails_the_target(self):
        source = self.root / "tree"
        self.write_tree(source)
        self.install_tool(status=9)
        result = self.run_script(source, source / "out")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cwhip-format failed", result.stdout + result.stderr)

    def test_empty_tree_fails_without_running_the_tool(self):
        source = self.root / "empty"
        source.mkdir()
        _, log = self.install_tool()
        result = self.run_script(source, source / "build")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cwhip-format", result.stdout + result.stderr)
        self.assertFalse(log.exists())

    def make_sdk(self):
        prefix = self.root / "sdk"
        package = prefix / "lib" / "cmake" / "Cwhip"
        package.mkdir(parents=True)
        (package / "CwhipConfigVersion.cmake").write_text(
            'set(PACKAGE_VERSION "0.0.2")\n'
            'if(PACKAGE_FIND_VERSION VERSION_EQUAL PACKAGE_VERSION)\n'
            '  set(PACKAGE_VERSION_EXACT TRUE)\n'
            '  set(PACKAGE_VERSION_COMPATIBLE TRUE)\n'
            'endif()\n', encoding="utf-8")
        (package / "CwhipConfig.cmake").write_text(
            'set(Cwhip_APPLICATION_OUTPUT_DIRECTORIES TRUE)\n'
            'set(Cwhip_SDK_ABI "numeric-v2")\n'
            f'set(Cwhip_PREFIX "{prefix}")\n'
            'function(cwhip_add_program name)\n'
            '  add_custom_target(${name})\n'
            '  set_target_properties(${name} PROPERTIES '
            'CWHIP_EXECUTABLE "${CMAKE_COMMAND}")\n'
            'endfunction()\n'
            'function(cwhip_apply_application_defaults)\n'
            'endfunction()\n',
            encoding="utf-8")
        return prefix

    def test_make_format_after_configure(self):
        before = {path: path.read_bytes()
                  for path in PROJECT.rglob("*.cw")}
        sdk = self.make_sdk()
        home = self.root / "home"
        config = self.root / "config"
        home.mkdir()
        config.mkdir()
        build = self.root / "build dir"
        self.env.update(HOME=str(home), XDG_CONFIG_HOME=str(config),
                        CWHIP_SDK=str(sdk), CWHIP_REGISTER_SDK="OFF")
        configured = subprocess.run(
            [CMAKE, "-S", str(PROJECT), "-B", str(build),
             "-DBUILD_TESTING=OFF"],
            env=self.env, capture_output=True, text=True)
        self.assertEqual(configured.returncode, 0,
                         configured.stdout + configured.stderr)
        self.assertTrue((build / "Makefile").is_file())

        missing = subprocess.run(
            ["make", "-C", str(build), "format"],
            env=self.env, capture_output=True, text=True)
        self.assertNotEqual(missing.returncode, 0,
                            missing.stdout + missing.stderr)
        self.assertIn("cwhip-format is not available",
                      missing.stdout + missing.stderr)

        tool, log = self.install_tool()
        default = subprocess.run(
            ["make", "-C", str(build)],
            env=self.env, capture_output=True, text=True)
        self.assertEqual(default.returncode, 0, default.stdout + default.stderr)
        self.assertFalse(log.exists())

        formatted = subprocess.run(
            ["make", "-C", str(build), "format"],
            env=self.env, capture_output=True, text=True)
        self.assertEqual(formatted.returncode, 0,
                         formatted.stdout + formatted.stderr)
        recorded = json.loads(log.read_text(encoding="utf-8"))
        self.assertEqual(Path(recorded["argv"][0]).resolve(), tool.resolve())
        self.assertEqual(recorded["argv"][1], "-i")
        self.assertEqual(Path(recorded["cwd"]).resolve(), PROJECT.resolve())
        seen = {Path(path).resolve() for path in recorded["argv"][2:]}
        expected = set()
        for path in PROJECT.rglob("*.cw"):
            relative = path.relative_to(PROJECT)
            if relative.parts[0] == "build":
                continue
            if build.resolve() in path.resolve().parents:
                continue
            expected.add(path.resolve())
        self.assertEqual(seen, expected)
        self.assertGreaterEqual(len(expected), 1)
        for path, data in before.items():
            self.assertEqual(path.read_bytes(), data)


if __name__ == "__main__":
    unittest.main()
