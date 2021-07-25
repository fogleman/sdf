package Alien::wxWidgets::Config::gtk2_3_0_2_uni_gcc_3_4;

use strict;

our %VALUES;

{
    no strict 'vars';
    %VALUES = %{
$VAR1 = {
          '_libraries' => {
                            'adv' => {
                                       'dll' => 'libwx_gtk2u_adv-3.0.so',
                                       'link' => '-lwx_gtk2u_adv-3.0'
                                     },
                            'animate' => {
                                           'dll' => 'libwx_gtk2u_animate-3.0.so',
                                           'link' => '-lwx_gtk2u_animate-3.0'
                                         },
                            'aui' => {
                                       'dll' => 'libwx_gtk2u_aui-3.0.so',
                                       'link' => '-lwx_gtk2u_aui-3.0'
                                     },
                            'base' => {
                                        'dll' => 'libwx_baseu-3.0.so',
                                        'link' => '-lwx_baseu-3.0'
                                      },
                            'core' => {
                                        'dll' => 'libwx_gtk2u_core-3.0.so',
                                        'link' => '-lwx_gtk2u_core-3.0'
                                      },
                            'fl' => {
                                      'dll' => 'libwx_gtk2u_fl-3.0.so',
                                      'link' => '-lwx_gtk2u_fl-3.0'
                                    },
                            'gizmos' => {
                                          'dll' => 'libwx_gtk2u_gizmos-3.0.so',
                                          'link' => '-lwx_gtk2u_gizmos-3.0'
                                        },
                            'gl' => {
                                      'dll' => 'libwx_gtk2u_gl-3.0.so',
                                      'link' => '-lwx_gtk2u_gl-3.0'
                                    },
                            'html' => {
                                        'dll' => 'libwx_gtk2u_html-3.0.so',
                                        'link' => '-lwx_gtk2u_html-3.0'
                                      },
                            'media' => {
                                         'dll' => 'libwx_gtk2u_media-3.0.so',
                                         'link' => '-lwx_gtk2u_media-3.0'
                                       },
                            'net' => {
                                       'dll' => 'libwx_baseu_net-3.0.so',
                                       'link' => '-lwx_baseu_net-3.0'
                                     },
                            'propgrid' => {
                                            'dll' => 'libwx_gtk2u_propgrid-3.0.so',
                                            'link' => '-lwx_gtk2u_propgrid-3.0'
                                          },
                            'qa' => {
                                      'dll' => 'libwx_gtk2u_qa-3.0.so',
                                      'link' => '-lwx_gtk2u_qa-3.0'
                                    },
                            'ribbon' => {
                                          'dll' => 'libwx_gtk2u_ribbon-3.0.so',
                                          'link' => '-lwx_gtk2u_ribbon-3.0'
                                        },
                            'richtext' => {
                                            'dll' => 'libwx_gtk2u_richtext-3.0.so',
                                            'link' => '-lwx_gtk2u_richtext-3.0'
                                          },
                            'stc' => {
                                       'dll' => 'libwx_gtk2u_stc-3.0.so',
                                       'link' => '-lwx_gtk2u_stc-3.0'
                                     },
                            'webview' => {
                                           'dll' => 'libwx_gtk2u_webview-3.0.so',
                                           'link' => '-lwx_gtk2u_webview-3.0'
                                         },
                            'xml' => {
                                       'dll' => 'libwx_baseu_xml-3.0.so',
                                       'link' => '-lwx_baseu_xml-3.0'
                                     },
                            'xrc' => {
                                       'dll' => 'libwx_gtk2u_xrc-3.0.so',
                                       'link' => '-lwx_gtk2u_xrc-3.0'
                                     }
                          },
          'alien_base' => 'gtk2_3_0_2_uni_gcc_3_4',
          'alien_package' => 'Alien::wxWidgets::Config::gtk2_3_0_2_uni_gcc_3_4',
          'c_flags' => '-pthread ',
          'compiler' => 'g++-4.9',
          'config' => {
                        'build' => 'multi',
                        'compiler_kind' => 'gcc',
                        'compiler_version' => '3.4',
                        'debug' => 0,
                        'mslu' => 0,
                        'toolkit' => 'gtk2',
                        'unicode' => 1
                      },
          'defines' => '-D_FILE_OFFSET_BITS=64 -DWXUSINGDLL -D__WXGTK__ ',
          'include_path' => '-I/home/travis/builds/alexrj/Slic3r/local-lib/lib/perl5/x86_64-linux-thread-multi/Alien/wxWidgets/gtk_3_0_2_uni/lib/wx/include/gtk2-unicode-3.0 -I/home/travis/builds/alexrj/Slic3r/local-lib/lib/perl5/x86_64-linux-thread-multi/Alien/wxWidgets/gtk_3_0_2_uni/include/wx-3.0 ',
          'link_flags' => '',
          'link_libraries' => ' -L/home/travis/builds/alexrj/Slic3r/local-lib/lib/perl5/x86_64-linux-thread-multi/Alien/wxWidgets/gtk_3_0_2_uni/lib -lpthread',
          'linker' => 'g++-4.9  ',
          'prefix' => '/home/travis/builds/alexrj/Slic3r/local-lib/lib/perl5/x86_64-linux-thread-multi/Alien/wxWidgets/gtk_3_0_2_uni',
          'version' => '3.000002'
        };
    };
}

my $key = substr __PACKAGE__, 1 + rindex __PACKAGE__, ':';

sub values { %VALUES, key => $key }

sub config {
   +{ %{$VALUES{config}},
      package       => __PACKAGE__,
      key           => $key,
      version       => $VALUES{version},
      }
}

1;
