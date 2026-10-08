"""Offline tests: python3 -m unittest discover -s tests -v."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which('bash')


class LspInstallTests(unittest.TestCase):
    def run_script(self, script, *args, env=None):
        return subprocess.run([BASH, str(ROOT / script), *args], env=env,
                              text=True, capture_output=True, timeout=20)

    def test_cli(self):
        cases = [([], 'none'), (['--lsp', 'python,rust'], 'python,rust'),
                 (['--lsp=cpp,js', '--lsp', 'py,cpp'], 'c,python,typescript'),
                 (['--with-lsp'], 'c,python,lua,rust,typescript'),
                 (['--lsp', 'none'], 'none')]
        for args, selection in cases:
            with self.subTest(args=args):
                result = self.run_script('install.sh', *args, '--dry-run')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('LSP 语言：' + selection + '\n', result.stdout)
        for args in [['--lsp'], ['--lsp='], ['--lsp', 'go'],
                     ['--lsp', 'python,'], ['--lsp', 'none,lua']]:
            with self.subTest(args=args):
                self.assertNotEqual(self.run_script('install.sh', *args, '--dry-run').returncode, 0)

    def test_server_install_is_scoped(self):
        # PATH contains only explicitly available dependencies. No network or system changes.
        for language, binaries, expected in [
            ('none', [], []), ('c', ['clangd'], []),
            ('lua', ['lua-language-server'], []),
            ('python', ['node', 'npm'], ['pyright@1.1.408']),
            ('typescript', ['node', 'npm'], ['typescript-language-server@5.1.3', 'typescript@5.9.3']),
            ('rust', ['rustup', 'rust-analyzer', 'cargo'], ['rustup component add']),
        ]:
            with self.subTest(language=language), tempfile.TemporaryDirectory() as tmp:
                base = Path(tmp)
                bindir = base / 'bin'
                bindir.mkdir()
                for name in ('bash', 'dirname', 'mkdir'):
                    (bindir / name).symlink_to(shutil.which(name))
                for name in binaries:
                    path = bindir / name
                    path.write_text('#!' + BASH + '\n'
                                    'echo "${0##*/} $*" >> "$TEST_TOOL_LOG"\n'
                                    'if [[ "${0##*/} $*" == "rustup show active-toolchain" ]]; then echo stable; fi\n'
                                    'exit 0\n')
                    path.chmod(0o755)
                env = dict(os.environ, PATH=str(bindir), XDG_DATA_HOME=str(base / 'data'),
                           CARGO_HOME=str(base / 'cargo'), TEST_TOOL_LOG=str(base / 'calls'))
                result = self.run_script('scripts/install-lsp.sh', language, env=env)
                self.assertEqual(result.returncode, 0, result.stderr)
                calls = (base / 'calls').read_text() if (base / 'calls').exists() else ''
                for item in expected:
                    self.assertIn(item, calls)
                if language != 'rust':
                    self.assertNotIn('rustup', calls)
                if language not in ('python', 'typescript'):
                    self.assertNotIn('npm', calls)
                if language == 'python':
                    self.assertNotIn('typescript@', calls)
                if language == 'typescript':
                    self.assertNotIn('pyright@', calls)

    def test_runtime_integrity(self):
        command = [shutil.which('nvim'), '--headless', '-u', 'NONE', '-i', 'NONE',
                   '-n', '-l', str(ROOT / 'scripts/check-runtime.lua')]
        result = subprocess.run(command, text=True, capture_output=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        # Same binary/version, but an incomplete runtime must not be reused.
        with tempfile.TemporaryDirectory() as runtime:
            result = subprocess.run(command, env=dict(os.environ, VIMRUNTIME=runtime),
                                    text=True, capture_output=True, timeout=20)
            self.assertNotEqual(result.returncode, 0)

    def test_runtime_selection(self):
        result = subprocess.run([shutil.which('nvim'), '--headless', '-u', 'NONE', '-i', 'NONE',
                                 '-n', '-l', 'tests/lsp-selection.lua'], cwd=ROOT,
                                text=True, capture_output=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
