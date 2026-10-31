#!/usr/bin/env bash
set -euo pipefail

# Generates GitHub Actions dynamic build matrix from images/*/image.json metadata
# Usage:
#   scripts/generate-matrix.sh [--image <image_name|all>] [--changed-files "<files>"]

SELECTED_IMAGE="all"
CHANGED_FILES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      SELECTED_IMAGE="$2"
      shift 2
      ;;
    --changed-files)
      CHANGED_FILES="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGES_DIR="${REPO_ROOT}/images"

perl -MJSON::PP -e '
  use strict;
  use warnings;

  my $images_dir = $ARGV[0];
  my $selected_image = $ARGV[1];
  my $changed_files = $ARGV[2] || "";

  my @changed = split(/\s+/, $changed_files);
  my %changed_images;
  for my $file (@changed) {
    if ($file =~ m{^images/([^/]+)/}) {
      $changed_images{$1} = 1;
    }
  }

  my @matrix_entries;
  opendir(my $dh, $images_dir) or die "Cannot open $images_dir: $!";
  my @subdirs = sort grep { -d "$images_dir/$_" && !/^\./ } readdir($dh);
  closedir($dh);

  for my $img (@subdirs) {
    # Filter by selected image if specified
    if ($selected_image ne "all" && $selected_image ne $img) {
      next;
    }

    # If changed files are provided, only include if changed
    if ($changed_files ne "" && $selected_image eq "all") {
      next unless exists $changed_images{$img};
    }

    my $config_path = "$images_dir/$img/image.json";
    next unless -f $config_path;

    open(my $fh, "<", $config_path) or die "Cannot read $config_path: $!";
    my $content = do { local $/; <$fh> };
    close($fh);

    my $json = decode_json($content);
    my $targets = $json->{targets} || [
      { name => $img, target => "", validation_arg => "", default => 1 }
    ];

    for my $target (@$targets) {
      my $build_args = "";
      if (ref($target->{build_args}) eq "HASH") {
        my @args;
        for my $k (sort keys %{$target->{build_args}}) {
          push @args, "$k=" . $target->{build_args}{$k};
        }
        $build_args = join("\n", @args);
      } elsif ($target->{build_args}) {
        $build_args = $target->{build_args};
      }

      push @matrix_entries, {
        image          => $img,
        dir            => "images/$img",
        target         => $target->{target} || "",
        image_name     => $target->{name} || $img,
        validation_arg => $target->{validation_arg} || "",
        build_args     => $build_args,
      };
    }
  }

  my $result = { include => \@matrix_entries };
  print encode_json($result);
' "$IMAGES_DIR" "$SELECTED_IMAGE" "$CHANGED_FILES"
