python3 << EndPython3
import collections
import os
import sys
import vim

BNB_FIXER = vim.eval('g:bnb_fixer').lower()
if BNB_FIXER not in {'black', 'blue'}:
  raise ValueError(f'Invalid setting g:bnb_fixer={BNB_FIXER}. Valid values are black and blue')

def strtobool(text):
  if text.lower() in ['y', 'yes', 't', 'true', 'on', '1']:
    return True
  if text.lower() in ['n', 'no', 'f', 'false', 'off', '0']:
    return False
  raise ValueError(f"{text} is not convertible to boolean")

class Flag(collections.namedtuple("FlagBase", "name, cast")):
  @property
  def var_name(self):
    return self.name.replace("-", "_")

  @property
  def vim_rc_name(self):
    name = self.var_name
    if name == "line_length":
      name = name.replace("_", "")
    return "g:bnb_" + name


FLAGS = [
  Flag(name="line_length", cast=int),
  Flag(name="fast", cast=strtobool),
  Flag(name="skip_string_normalization", cast=strtobool),
  Flag(name="quiet", cast=strtobool),
  Flag(name="skip_magic_trailing_comma", cast=strtobool),
  Flag(name="preview", cast=strtobool),
]


def _get_python_binary(exec_prefix, pyver):
  try:
    default = vim.eval("g:pymode_python").strip()
  except vim.error:
    default = ""
  if default and os.path.exists(default):
    return default
  if sys.platform[:3] == "win":
    return exec_prefix / 'python.exe'
  bin_path = exec_prefix / "bin"
  exec_path = (bin_path / f"python{pyver[0]}.{pyver[1]}").resolve()
  if exec_path.exists():
    return exec_path
  # It is possible that some environments may only have python3
  exec_path = (bin_path / f"python3").resolve()
  if exec_path.exists():
    return exec_path
  raise ValueError("python executable not found")

def _get_pip(venv_path):
  if sys.platform[:3] == "win":
    return venv_path / 'Scripts' / 'pip.exe'
  return venv_path / 'bin' / 'pip'

def _get_virtualenv_site_packages(venv_path, pyver):
  if sys.platform[:3] == "win":
    return venv_path / 'Lib' / 'site-packages'
  return venv_path / 'lib' / f'python{pyver[0]}.{pyver[1]}' / 'site-packages'

def _initialize_bnb_env(upgrade=False):
  if vim.eval("g:bnb_use_virtualenv ? 'true' : 'false'") == "false":
    if upgrade:
      print("Upgrade disabled due to g:bnb_use_virtualenv being disabled.")
      print(f"Either use your system package manager (or pip) to upgrade {BNB_FIXER} separately,")
      print("or modify your vimrc to have 'let g:bnb_use_virtualenv = 1'.")
      return False
    else:
      # Nothing needed to be done.
      return True

  pyver = sys.version_info[:3]
  if pyver < (3, 7):
    print(f"Sorry, {BNB_FIXER} requires Python 3.7+ to run.")
    return False

  from pathlib import Path
  import subprocess
  import venv
  virtualenv_path = Path(vim.eval("g:bnb_virtualenv")).expanduser()
  virtualenv_site_packages = str(_get_virtualenv_site_packages(virtualenv_path, pyver))
  first_install = False
  if not virtualenv_path.is_dir():
    print(f'Please wait, one time setup for {BNB_FIXER}.')
    _executable = sys.executable
    _base_executable = getattr(sys, "_base_executable", _executable)
    try:
      executable = str(_get_python_binary(Path(sys.exec_prefix), pyver))
      sys.executable = executable
      sys._base_executable = executable
      print(f'Creating a virtualenv in {virtualenv_path}...')
      print('(this path can be customized in .vimrc by setting g:bnb_virtualenv)')
      venv.create(virtualenv_path, with_pip=True)
    except Exception:
      print('Encountered exception while creating virtualenv (see traceback below).')
      print(f'Removing {virtualenv_path}...')
      import shutil
      shutil.rmtree(virtualenv_path)
      raise
    finally:
      sys.executable = _executable
      sys._base_executable = _base_executable
    first_install = True
  if first_install:
    print(f'Installing {BNB_FIXER} with pip...')
  if upgrade:
    print(f'Upgrading {BNB_FIXER} with pip...')
  if first_install or upgrade:
    subprocess.run([str(_get_pip(virtualenv_path)), 'install', '-U', BNB_FIXER], stdout=subprocess.PIPE)
    print('DONE! You are all set, thanks for waiting ✨ 🍰 ✨')
  if first_install:
    print(f'Pro-tip: to upgrade {BNB_FIXER} in the future, use the :BnbUpgrade command and restart Vim.\n')
  if virtualenv_site_packages not in sys.path:
    sys.path.insert(0, virtualenv_site_packages)
  return True

if _initialize_bnb_env():
  if BNB_FIXER == 'black':
    import black as bnb
  elif BNB_FIXER == 'blue':
    import blue as bnb
  import time

def get_target_version(tv):
  if isinstance(tv, bnb.TargetVersion):
    return tv
  ret = None
  try:
    ret = bnb.TargetVersion[tv.upper()]
  except KeyError:
    print(f"WARNING: Target version {tv!r} not recognized by Black, using default target")
  return ret

def Bnb(**kwargs):
  """
  kwargs allows you to override ``target_versions`` argument of
  ``black.FileMode``.

  ``target_version`` needs to be cleaned because ``black.FileMode``
  expects the ``target_versions`` argument to be a set of TargetVersion enums.

  Allow kwargs["target_version"] to be a string to allow
  to type it more quickly.

  Using also target_version instead of target_versions to remain
  consistent to Black's documentation of the structure of pyproject.toml.
  """
  start = time.time()
  configs = get_configs()

  bnb_kwargs = {}
  if "target_version" in kwargs:
    target_version = kwargs["target_version"]

    if not isinstance(target_version, (list, set)):
      target_version = [target_version]
    target_version = set(filter(lambda x: x, map(lambda tv: get_target_version(tv), target_version)))
    bnb_kwargs["target_versions"] = target_version

  if BNB_FIXER == 'black':
    FM = bnb.FileMode
  elif BNB_FIXER == 'blue':
    FM = bnb.black.FileMode

  mode = FM(
    line_length=configs["line_length"],
    string_normalization=not configs["skip_string_normalization"],
    is_pyi=vim.current.buffer.name.endswith('.pyi'),
    magic_trailing_comma=not configs["skip_magic_trailing_comma"],
    preview=configs["preview"],
    **bnb_kwargs,
  )
  quiet = configs["quiet"]

  buffer_str = '\n'.join(vim.current.buffer) + '\n'
  try:
    if BNB_FIXER == 'black':
      format_file_contents = bnb.format_file_contents
    else:
      bnb.monkey_patch_black(bnb.Mode.asynchronous)
      format_file_contents = bnb.black.format_file_contents

    new_buffer_str = format_file_contents(
      buffer_str,
      fast=configs["fast"],
      mode=mode,
    )
  except bnb.NothingChanged:
    if not quiet:
      print(f'{BNB_FIXER}: already well formatted, good job. (took {time.time() - start:.4f}s)')
  except Exception as exc:
    print(f'{BNB_FIXER}: {exc}')
  else:
    current_buffer = vim.current.window.buffer
    cursors = []
    for i, tabpage in enumerate(vim.tabpages):
      if tabpage.valid:
        for j, window in enumerate(tabpage.windows):
          if window.valid and window.buffer == current_buffer:
            cursors.append((i, j, window.cursor))
    vim.current.buffer[:] = new_buffer_str.split('\n')[:-1]
    for i, j, cursor in cursors:
      window = vim.tabpages[i].windows[j]
      try:
        window.cursor = cursor
      except vim.error:
        window.cursor = (len(window.buffer), 0)
    if not quiet:
      print(f'{BNB_FIXER}: reformatted in {time.time() - start:.4f}s.')

def get_configs():
  filename = vim.eval("@%")
  if BNB_FIXER == 'black':
    path_pyproject_toml = bnb.find_pyproject_toml((filename,))
    if path_pyproject_toml:
      toml_config = bnb.parse_pyproject_toml(path_pyproject_toml)
    else:
      toml_config = {}
  elif BNB_FIXER == 'blue':
    path_pyproject_toml = bnb.black.find_pyproject_toml((filename,))
    if path_pyproject_toml:
      toml_config = bnb.black.parse_pyproject_toml(path_pyproject_toml)
    else:
      toml_config = {}

  print(toml_config)

  return {
    flag.var_name: toml_config.get(flag.name, flag.cast(vim.eval(flag.vim_rc_name)))
    for flag in FLAGS
  }


def BnbUpgrade():
  _initialize_bnb_env(upgrade=True)

def BnbVersion():
  print(f'{BNB_FIXER}, version {bnb.__version__} on Python {sys.version}.')

EndPython3

function bnb#Bnb(...)
    let kwargs = {}
    for arg in a:000
        let arg_list = split(arg, '=')
        let kwargs[arg_list[0]] = arg_list[1]
    endfor
python3 << EOF
import vim
kwargs = vim.eval("kwargs")
EOF
  :py3 Bnb(**kwargs)
endfunction

function bnb#BnbUpgrade()
  :py3 BnbUpgrade()
endfunction

function bnb#BnbVersion()
  :py3 BnbVersion()
endfunction
