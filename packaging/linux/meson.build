desktop_conf = configuration_data()
desktop_conf.set('APP_NAME', bundle_name)

configure_file(
    input:  'app.desktop.in',
    output: bundle_name + '.desktop',
    configuration: desktop_conf,
)
pkg_build_dir = meson.current_build_dir()
