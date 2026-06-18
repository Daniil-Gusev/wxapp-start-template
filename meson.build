project('wxExample', 'cpp',
    version: '0.1.0',
    default_options: ['cpp_std=c++20', 'buildtype=plain', 'warning_level=3', 'unity=on']
)

cpp = meson.get_compiler('cpp')
host_system = host_machine.system()
project_args = []
dependencies = []

cpu = host_machine.cpu_family()
if cpp.get_id() != 'msvc'
    if cpu == 'x86_64'
        project_args += '-m64'
    elif cpu == 'x86'
        project_args += '-m32'
    endif
endif

wx_dep = dependency('wxwidgets', required: true)
dependencies += wx_dep

git = find_program('git', required: false)
git_rev = 'unknown'
if git.found()
    git_rev = run_command(git, 'rev-parse', '--short', 'HEAD', check: false).stdout().strip()
endif

conf_data = configuration_data()
conf_data.set('PROJECT_NAME', meson.project_name())
conf_data.set('PROJECT_VERSION', meson.project_version())
conf_data.set('PROJECT_REVISION', git_rev)

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
    'src/mainpanel.cpp',
    'src/mainframe.cpp',
    'src/app.cpp'
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
    install: true
)

if host_system == 'darwin'
    bundle_conf = configuration_data()
    bundle_conf.set('BUNDLE_NAME',       bundle_name)
    bundle_conf.set('BUNDLE_IDENTIFIER', 'com.example.' + bundle_name.to_lower())
    bundle_conf.set('PROJECT_VERSION',   meson.project_version())

    plist_out = configure_file(
        input:         'packaging/macos/Info.plist.in',
        output:        'Info.plist',
        configuration: bundle_conf,
    )

    meson.add_install_script(
        find_program('python3'),
        meson.project_source_root() / 'packaging' / 'macos' / 'make_bundle.py',
        bundle_name,
        meson.project_version(),
    )
endif

subdir('locale')
