package Alien::wxWidgets::Config::msw_3_1_0_uni_gcc_3_4;

use strict;

our %VALUES;

{
    no strict 'vars';
    %VALUES = %{
$VAR1 = {
          'alien_base' => 'msw_3_1_0_uni_gcc_3_4',
          'linker' => 'g++',
          'link_libraries' => '-LC:\\users\\lenox\\slic3r\\LOCAL-~1\\lib\\perl5\\MSWin32-x64-multi-thread\\Alien\\wxWidgets\\msw_3_1_0_uni_gcc_3_4\\lib -lwxmsw31u_core -lwxbase31u ',
          'defines' => '-DHAVE_W32API_H -D__WXMSW__ -DNDEBUG -D_UNICODE -DWXUSINGDLL -DNOPCH -DNO_GCC_PRAGMA ',
          'version' => '3.001000',
          'shared_library_path' => 'C:\\users\\lenox\\slic3r\\LOCAL-~1\\lib\\perl5\\MSWin32-x64-multi-thread\\Alien\\wxWidgets\\msw_3_1_0_uni_gcc_3_4\\lib',
          'c_flags' => ' -m64  -O2 -mthreads -m64 -Os ',
          'compiler' => 'g++',
          'link_flags' => ' -s -m64 ',
          'wx_base_directory' => 'C:\\users\\lenox\\slic3r\\LOCAL-~1\\lib\\perl5\\MSWin32-x64-multi-thread\\Alien\\wxWidgets\\msw_3_1_0_uni_gcc_3_4',
          'config' => {
                        'build' => 'multi',
                        'unicode' => 1,
                        'compiler_version' => '3.4',
                        'toolkit' => 'msw',
                        'mslu' => 0,
                        'compiler_kind' => 'gcc',
                        'debug' => 0
                      },
          '_libraries' => {
                            'richtext' => {
                                            'dll' => 'wxmsw310u_richtext_gcc_custom.dll',
                                            'lib' => 'libwxmsw31u_richtext.a',
                                            'link' => '-lwxmsw31u_richtext'
                                          },
                            'ribbon' => {
                                          'link' => '-lwxmsw31u_ribbon',
                                          'lib' => 'libwxmsw31u_ribbon.a',
                                          'dll' => 'wxmsw310u_ribbon_gcc_custom.dll'
                                        },
                            'xrc' => {
                                       'link' => '-lwxmsw31u_xrc',
                                       'lib' => 'libwxmsw31u_xrc.a',
                                       'dll' => 'wxmsw310u_xrc_gcc_custom.dll'
                                     },
                            'base' => {
                                        'dll' => 'wxbase310u_gcc_custom.dll',
                                        'link' => '-lwxbase31u',
                                        'lib' => 'libwxbase31u.a'
                                      },
                            'xml' => {
                                       'dll' => 'wxbase310u_xml_gcc_custom.dll',
                                       'link' => '-lwxbase31u_xml',
                                       'lib' => 'libwxbase31u_xml.a'
                                     },
                            'media' => {
                                         'dll' => 'wxmsw310u_media_gcc_custom.dll',
                                         'lib' => 'libwxmsw31u_media.a',
                                         'link' => '-lwxmsw31u_media'
                                       },
                            'propgrid' => {
                                            'lib' => 'libwxmsw31u_propgrid.a',
                                            'link' => '-lwxmsw31u_propgrid',
                                            'dll' => 'wxmsw310u_propgrid_gcc_custom.dll'
                                          },
                            'gl' => {
                                      'link' => '-lwxmsw31u_gl',
                                      'lib' => 'libwxmsw31u_gl.a',
                                      'dll' => 'wxmsw310u_gl_gcc_custom.dll'
                                    },
                            'stc' => {
                                       'dll' => 'wxmsw310u_stc_gcc_custom.dll',
                                       'lib' => 'libwxmsw31u_stc.a',
                                       'link' => '-lwxmsw31u_stc'
                                     },
                            'html' => {
                                        'link' => '-lwxmsw31u_html',
                                        'lib' => 'libwxmsw31u_html.a',
                                        'dll' => 'wxmsw310u_html_gcc_custom.dll'
                                      },
                            'adv' => {
                                       'link' => '-lwxmsw31u_adv',
                                       'lib' => 'libwxmsw31u_adv.a',
                                       'dll' => 'wxmsw310u_adv_gcc_custom.dll'
                                     },
                            'net' => {
                                       'link' => '-lwxbase31u_net',
                                       'lib' => 'libwxbase31u_net.a',
                                       'dll' => 'wxbase310u_net_gcc_custom.dll'
                                     },
                            'webview' => {
                                           'dll' => 'wxmsw310u_webview_gcc_custom.dll',
                                           'link' => '-lwxmsw31u_webview',
                                           'lib' => 'libwxmsw31u_webview.a'
                                         },
                            'core' => {
                                        'lib' => 'libwxmsw31u_core.a',
                                        'link' => '-lwxmsw31u_core',
                                        'dll' => 'wxmsw310u_core_gcc_custom.dll'
                                      },
                            'aui' => {
                                       'dll' => 'wxmsw310u_aui_gcc_custom.dll',
                                       'lib' => 'libwxmsw31u_aui.a',
                                       'link' => '-lwxmsw31u_aui'
                                     }
                          },
          'include_path' => '-IC:\\users\\lenox\\slic3r\\LOCAL-~1\\lib\\perl5\\MSWin32-x64-multi-thread\\Alien\\wxWidgets\\msw_3_1_0_uni_gcc_3_4\\lib -IC:\\users\\lenox\\slic3r\\LOCAL-~1\\lib\\perl5\\MSWin32-x64-multi-thread\\Alien\\wxWidgets\\msw_3_1_0_uni_gcc_3_4\\include -IC:\\users\\lenox\\slic3r\\LOCAL-~1\\lib\\perl5\\MSWin32-x64-multi-thread\\Alien\\wxWidgets\\msw_3_1_0_uni_gcc_3_4\\include ',
          'alien_package' => 'Alien::wxWidgets::Config::msw_3_1_0_uni_gcc_3_4',
          'prefix' => 'C:\\users\\lenox\\slic3r\\LOCAL-~1\\lib\\perl5\\MSWin32-x64-multi-thread\\Alien\\wxWidgets\\msw_3_1_0_uni_gcc_3_4'
        };
    };
}

my $key = substr __PACKAGE__, 1 + rindex __PACKAGE__, ':';

my ($portablebase);
my $wxwidgetspath = __PACKAGE__ . '.pm';
$wxwidgetspath =~ s/::/\//g;

for (@INC) {
    if( -f qq($_/$wxwidgetspath ) ) {
        $portablebase = qq($_/Alien/wxWidgets/$key);
        last;
    }
}

if( $portablebase ) {
    $portablebase =~ s{/}{\\}g;
    my $portablelibpath = qq($portablebase\\lib);
    my $portableincpath = qq($portablebase\\include);

    $VALUES{include_path} = qq{-I$portablelibpath -I$portableincpath};
    $VALUES{link_libraries} =~ s{-L\S+\s}{-L$portablelibpath };
    $VALUES{shared_library_path} = $portablelibpath;
    $VALUES{wx_base_directory} = $portablebase;
    $VALUES{prefix} = $portablebase;
}

sub values { %VALUES, key => $key }

sub config {
   +{ %{$VALUES{config}},
      package       => __PACKAGE__,
      key           => $key,
      version       => $VALUES{version},
      }
}

1;
