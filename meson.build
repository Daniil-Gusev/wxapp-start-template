project('wxExample', 'cpp',
    version: '0.1.0',
    default_options: ['cpp_std=c++20', 'buildtype=plain', 'warning_level=3', 'unity=on', 'b_vscrt=static_from_buildtype']
)

cpp = meson.get_compiler('cpp')
host_system = host_machine.system()
project_args = []
dependencies = []

cpu = host_machine.cpu_family()
py3 = find_program('python3')

wx_modules = ['core', 'base', 'html']
if get_option('with_webview') == true
    wx_modules += 'webview'
endif

wx_dep = dependency('wxwidgets', required: true, modules: wx_modules)
dependencies += wx_dep

git = find_program('git', required: false)
git_rev = 'unknown'
if git.found()
    git_rev = run_command(git, 'rev-parse', '--short', 'HEAD', check: false).stdout().strip()
endif

subdir('packaging')

conf_data = configuration_data()
conf_data.set('PROJECT_NAME',     meson.project_name())
conf_data.set('PROJECT_VERSION',  meson.project_version())
conf_data.set('PROJECT_REVISION', git_rev)
conf_data.set('APP_VENDOR',       vendor_name)
conf_data.set('APP_DESCRIPTION',  app_description)
conf_data.set('APP_COPYRIGHT',    '(c) ' + copyright_year + ' ' + copyright_holder)

version_cpp = configure_file(
    input: 'src/version.cpp.in',
    output: 'version.cpp',
    configuration: conf_data
)

platform_sources = []

if host_system == 'windows'
    windows = import('windows')
    wx_cxxflags = wx_dep.get_variable(configtool: 'cxxflags').split()
    windres_args = wx_cxxflags + ['-I' + meson.project_source_root()]
    platform_sources += windows.compile_resources(
        'packaging/windows/app.rc',
        args: windres_args
    )
endif

main_sources = files(
    'src/ui/app.cpp',
    'src/ui/mainframe.cpp',
    'src/ui/mainpanel.cpp',
)

use_pch = get_option('b_pch')
pch_headers = []
if use_pch
    pch_headers = ['src/pch.h']
endif

bundle_name = meson.project_name()
app_ex = executable(bundle_name,
    [main_sources, platform_sources, version_cpp],
    include_directories: include_directories('src'),
    dependencies: dependencies,
    cpp_args: project_args,
    cpp_pch: pch_headers,
    win_subsystem: 'windows',
    install: true
)

dep_check_tool = ''
dep_check_kind = ''
dep_check_wx_libs = []

if host_system == 'windows'
    if cpp.get_id() in ['msvc', 'clang-cl']
        dep_check_kind = 'dumpbin'
        dep_check_prog = find_program('dumpbin', required: false)
    else
        dep_check_kind = 'objdump'
        dep_check_prog = find_program('objdump', required: false)
    endif
    if dep_check_prog.found()
        dep_check_tool = dep_check_prog.full_path()
    endif
elif host_system == 'linux'
    dep_check_kind = 'ldd'
    dep_check_prog = find_program('ldd', required: false)
    if dep_check_prog.found()
        dep_check_tool = dep_check_prog.full_path()
    endif
    wx_libs_flags = wx_dep.get_variable(configtool: 'libs', default_value: '').split()
    foreach flag : wx_libs_flags
        if flag.startswith('-lwx')
            dep_check_wx_libs += flag.substring(2)
        endif
    endforeach
endif

pkg_build_dir = ''
if host_system == 'darwin'
    subdir('packaging/macos')
elif host_system == 'windows'
    subdir('packaging/windows')
elif host_system == 'linux'
    subdir('packaging/linux')
endif

run_target('package',
    command: [
        py3,
        meson.project_source_root() / 'packaging' / 'package.py',
        bundle_name,
        meson.project_version(),
        meson.project_build_root(),
        meson.project_source_root(),
        host_system,
        get_option('prefix')
    ],
    env: [
        'DEP_CHECK_TOOL=' + dep_check_tool,
        'DEP_CHECK_KIND=' + dep_check_kind,
        'DEP_CHECK_WX_LIBS=' + ':'.join(dep_check_wx_libs),
        'TARGET_ARCH=' + cpu,
        'PKG_BUILD_DIR=' + pkg_build_dir,
    ]
)

subdir('locale')
