desktop_conf = configuration_data()
desktop_conf.set('APP_NAME', bundle_name)

configure_file(
    input:  'app.desktop.in',
    output: bundle_name + '.desktop',
    configuration: desktop_conf,
    install: true,
    install_dir: get_option('datadir') / 'applications',
)

install_data(
    meson.project_source_root() / 'assets' / 'app.png',
    install_dir: get_option('datadir') / 'icons' / 'hicolor' / '32x32' / 'apps',
    rename: bundle_name + '.png',
)

pkg_build_dir = meson.current_build_dir()
