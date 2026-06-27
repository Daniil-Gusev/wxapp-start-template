if cpu == 'x86_64'
    program_files_dir = '$PROGRAMFILES64'
    set_reg_view      = 'SetRegView 64'
else
    program_files_dir = '$PROGRAMFILES32'
    set_reg_view      = 'SetRegView 32'
endif

windows_conf = configuration_data()
windows_conf.set('APP_NAME',          bundle_name)
windows_conf.set('APP_VERSION',       meson.project_version())
windows_conf.set('PROGRAM_FILES_DIR', program_files_dir)
windows_conf.set('SET_REG_VIEW',      set_reg_view)

configure_file(
    input:  'installer.nsi.in',
    output: 'installer.nsi',
    configuration: windows_conf,
)

pkg_build_dir = meson.current_build_dir()
