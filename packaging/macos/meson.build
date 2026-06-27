macos_conf = configuration_data()
macos_conf.set('BUNDLE_NAME',       bundle_name)
macos_conf.set('BUNDLE_IDENTIFIER', bundle_id_prefix + '.' + bundle_name.to_lower())
macos_conf.set('PROJECT_VERSION',   meson.project_version())

configure_file(
    input:  'Info.plist.in',
    output: 'Info.plist',
    configuration: macos_conf,
)
pkg_build_dir = meson.current_build_dir()
