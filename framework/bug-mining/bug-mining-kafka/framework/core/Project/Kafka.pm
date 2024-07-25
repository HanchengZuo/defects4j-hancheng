#-------------------------------------------------------------------------------
# Copyright (c) 2014-2019 René Just, Darioush Jalali, and Defects4J contributors.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#-------------------------------------------------------------------------------

=pod

=head1 NAME

Project::Kafka.pm -- L<Project> submodule for Kafka.

=head1 DESCRIPTION

This module provides all project-specific configurations and methods for the
Kafka project.

=cut
package Project::Kafka;

use strict;
use warnings;

use Constants;
use Vcs::Git;

our @ISA = qw(Project);
my $PID  = "Kafka";

sub new {
    @_ == 1 or die $ARG_ERROR;
    my ($class) = @_;

    my $name = "kafka";
    my $vcs  = Vcs::Git->new($PID,
                             "$REPO_DIR/$name.git",
                             "$PROJECTS_DIR/$PID/$BUGS_CSV_ACTIVE",
                             \&_post_checkout);

    return $class->SUPER::new($PID, $name, $vcs);
}

sub _post_checkout {
    my ($self, $rev_id, $work_dir) = @_;

    # Change Url to Gradle distribution
    my $prop = "$work_dir/gradle/wrapper/gradle-wrapper.properties";
    my $lib_dir = "$BUILD_SYSTEMS_LIB_DIR/gradle/dists";

    # Read existing Gradle properties file, if it exists
    open(PROP, "<$prop") or return;
    my @tmp;
    my $gradle_version;
    while (<PROP>) {
        if (/distributionUrl=.*gradle-(.*)-all.zip/) {
            $gradle_version = $1; # Extract the Gradle version
        }
        push(@tmp, $_);
    }
    close(PROP);

    # If gradle_version is found, update distributionUrl
    if ($gradle_version) {
        for (@tmp) {
            s|(distributionUrl=).*|$1file\:$lib_dir/gradle-$gradle_version-all.zip|;
        }

        # Update properties file
        open(OUT, ">$prop") or die "Cannot write properties file";
        print(OUT @tmp);
        close(OUT);
    } else {
        warn "Gradle version not found in $prop";
    }

    # Disable the Gradle daemon and other properties if gradle.properties exists
    my $gradle_properties_file = "$work_dir/gradle.properties";
    if (-e $gradle_properties_file) {
        # Read existing Gradle properties file
        open(GRADLE_PROP, "<$gradle_properties_file") or die "Cannot open $gradle_properties_file";
        my @gradle_prop_lines = <GRADLE_PROP>;
        close(GRADLE_PROP);

        # Update properties if they exist, otherwise add them
        my %properties = (
            'org.gradle.parallel' => 'true',
            'org.gradle.daemon' => 'false',
            'org.gradle.configureondemand' => 'false'
        );

        foreach my $key (keys %properties) {
            my $found = 0;
            for my $line (@gradle_prop_lines) {
                if ($line =~ /^$key=/) {
                    $line = "$key=$properties{$key}\n";
                    $found = 1;
                    last;
                }
            }
            push @gradle_prop_lines, "$key=$properties{$key}\n" unless $found;
        }

        # Write updated properties back to the file
        open(GRADLE_PROP, ">$gradle_properties_file") or die "Cannot write $gradle_properties_file";
        print GRADLE_PROP @gradle_prop_lines;
        close(GRADLE_PROP);
    }

    # Enable local repository
    system("find $work_dir -type f -name \"build.gradle\" -exec sed -i.bak 's|jcenter()|maven { url \"$BUILD_SYSTEMS_LIB_DIR/gradle/deps\" }\\\n maven { url \"https://jcenter.bintray.com/\" }\\\n|g' {} \\;");

    # # Ensure dependencies are referenced correctly
    # _ensure_dependencies($work_dir);
}

# # Ensure dependencies are referenced correctly
# sub _ensure_dependencies {
#     my ($work_dir) = @_;

#     my $lib_dir = "$work_dir/build/libs";  # Define the directory to store dependencies

#     # Debug code: Print the lib_dir path
#     print "Dependency directory: $lib_dir\n";

#     # Traverse each dependency and reference them
#     opendir my $dir, $lib_dir or die "Cannot open directory: $lib_dir";
#     my @dependencies = grep { /\.jar$/ } readdir($dir);
#     closedir $dir;

#     foreach my $jar (@dependencies) {
#         my $jar_path = "$lib_dir/$jar";
#         unless (-e $jar_path) {
#             die "Dependency $jar is missing in $lib_dir. Please ensure it is placed there.";
#         }
#     }
# }

sub determine_layout {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $rev_id) = @_;
    my $work_dir = $self->{prog_root};

    # Define subproject directories
    my @subprojects = (
        'clients',
        'connect/api',
        'connect/basic-auth-extension',
        'connect/file',
        'connect/json',
        'connect/mirror',
        'connect/mirror-client',
        'connect/runtime',
        'connect/transforms',
        'core',
        'examples',
        'generator',
        'jmh-benchmarks',
        'log4j-appender',
        'metadata',
        'raft',
        'server-common',
        'shell',
        'storage',
        'storage/api',
        'streams',
        'streams/examples',
        'streams/streams-scala',
        'streams/test-utils',
        'streams/upgrade-system-tests-0100',
        'streams/upgrade-system-tests-0101',
        'streams/upgrade-system-tests-0102',
        'streams/upgrade-system-tests-0110',
        'streams/upgrade-system-tests-10',
        'streams/upgrade-system-tests-11',
        'streams/upgrade-system-tests-20',
        'streams/upgrade-system-tests-21',
        'streams/upgrade-system-tests-22',
        'streams/upgrade-system-tests-23',
        'streams/upgrade-system-tests-24',
        'tools',
        'trogdor',
    );

    my %layouts;

    # Traverse subproject directories and check layouts
    foreach my $subproject (@subprojects) {
        if (-e "$work_dir/$subproject/src/main/java" && -e "$work_dir/$subproject/src/test/java") {
            $layouts{$subproject} = { src => "$subproject/src/main/java", test => "$subproject/src/test/java" };
        } else {
            print "Skipping subproject: $subproject (either source or test directory not found)\n";
        }
    }

    # Default layout
    unless (%layouts) {
        if (-e "$work_dir/src/main/java" && -e "$work_dir/src/test/java") {
            $layouts{main} = { src => "$work_dir/src/main/java", test => "$work_dir/src/test/java" };
        } elsif (-e "$work_dir/src" && -e "$work_dir/test") {
            $layouts{main} = { src => "$work_dir/src", test => "$work_dir/test" };
        } else {
            die "Unknown directory layout";
        }
    }

    return \%layouts;
}

sub _ant_call {
    @_ >= 2 or die $ARG_ERROR;
    my ($self, $target, $option_str, $log_file) =  @_;

    # By default gradle uses $HOME/.gradle, which causes problems when multiple
    # instances of gradle run at the same time.
    #
    # TODO: Extract all exported environment variables into a user-visible
    # config file.
    $ENV{'GRADLE_USER_HOME'} = "$self->{prog_root}/$GRADLE_LOCAL_HOME_DIR";
    return $self->SUPER::_ant_call($target, $option_str, $log_file);
}

1;
