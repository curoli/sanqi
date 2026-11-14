#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint sanqi_mobile.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'sanqi_mobile'
  s.version          = '0.0.1'
  s.summary          = 'Native Rust game sessions for Sanqi.'
  s.description      = <<-DESC
Builds and links the Sanqi mobile Rust workspace crate.
                       DESC
  s.homepage         = 'https://github.com/curoli/sanqi'
  s.license          = { :type => 'MIT', :file => '../../../../LICENSE' }
  s.author           = 'Sanqi contributors'

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.script_phase = {
    :name => 'Build Rust library',
    # First argument is relative path to the `rust` folder, second is name of rust library
    :script => 'bash "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../../../../crates/sanqi-mobile sanqi_mobile',
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    # Let XCode know that the static library referenced in -force_load below is
    # created by this build step.
    :output_files => ["${BUILT_PRODUCTS_DIR}/libsanqi_mobile.a"],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Flutter.framework does not contain a i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/libsanqi_mobile.a',
  }
end
