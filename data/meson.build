icon_sizes = ['128']

foreach i : icon_sizes
    install_data(
        join_paths('icons', i, meson.project_name() + '.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i, 'apps'),
    )
    install_data(
        join_paths('icons', i, meson.project_name() + '.svg'),
        install_dir: join_paths(
            get_option('datadir'),
            'icons',
            'hicolor',
            i + 'x' + i + '@2',
            'apps',
        ),
    )
endforeach

install_data(
    join_paths('icons', '128', meson.project_name() + '-symbolic.svg'),
    install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'symbolic', 'apps'),
)

install_data(
    meson.project_name() + '.gschema.xml',
    install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas'),
)

datadir = join_paths(get_option('datadir'))
pkgdatadir = join_paths(datadir, meson.project_name())
service_conf = configuration_data()
service_conf.set('PACKAGE_NAME', meson.project_name())
service_conf.set('pkgdatadir', pkgdatadir)

configure_file(
    input: 'com.fyralabs.Kairos.service.in',
    output: app_id + '.service',
    configuration: service_conf,
    install: true,
    install_dir: join_paths(datadir, 'dbus-1', 'services'),
)