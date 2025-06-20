project('com.fyralabs.Kairos', 'vala', version: '0.1.0')

gnome = import('gnome')
i18n = import('i18n')

if get_option('development')
  app_id = 'com.fyralabs.Kairos'
  name_suffix = ' (Development)'
else
  app_id = 'com.fyralabs.Kairos'
  name_suffix = ''
endif

conf = configuration_data()
conf.set_quoted('APP_ID', app_id)
conf.set_quoted('NAME_SUFFIX', name_suffix)
conf.set_quoted('VERSION', meson.project_version())
conf.set_quoted('GETTEXT_PACKAGE', app_id)
conf.set_quoted('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
conf.set10('DEVELOPMENT', get_option('development'))
configure_file(output: 'config.h', configuration: conf)
config_h_dir = include_directories('.')

add_project_arguments(
  '-include', 'config.h',
  '-w',
  '-DGETTEXT_PACKAGE="@0@"'.format(app_id),
  language: 'c',
)

asresources = gnome.compile_resources(
  'as-resources',
  'data/com.fyralabs.Kairos.gresource.xml',
  source_dir: 'data',
  c_name: 'as',
)

sources = [
  'src/Application.vala',
  'src/MainWindow.vala',
  'src/SunGraph.vala',
  'src/WeatherPage.vala',
  'src/WeatherGraph.vala',
  'src/WeatherHumidityRow.vala',
  'src/WeatherRow.vala',
  'src/WorldLocationFinder.vala',
  'src/Utils.vala',
]

gweather = dependency('gweather4', version: '>= 3.90.0')
libbismuth_dep = meson.get_compiler('c').find_library('libbismuth', required: false)
cc = meson.get_compiler('c')
math = cc.find_library('m', required: false)
dependencies = [
  dependency('gio-2.0'),
  dependency('gtk4'),
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gee-0.8'),
  dependency('libhelium-1'),
  dependency(
    'libbismuth-1',
    fallback: ['libbismuth', 'libbismuth_dep'],
    version: '>=1.0.0',
  ),
  dependency('geocode-glib-2.0', version: '>=1.0'),
  gweather,
  math,
  dependency('libgeoclue-2.0', version: '>= 0.12.99'),
  dependency('gmodule-2.0'),
]

executable(
  meson.project_name(),
  sources,
  asresources,
  dependencies: dependencies,
  vala_args: [meson.project_source_root() + '/src/Config.vapi'],
  install: true,
)

subdir('data')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
