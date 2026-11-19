#!/usr/bin/env perl
# Run the pinned desktop replay engine with SDL's dummy video/audio drivers.
# The hooks only observe the game or remove sprites from the static backdrop.
use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use JSON::PP qw(encode_json);
use File::Path qw(make_path);
use File::Spec;
my ($root, $out, $number, $reference) = @ARGV;
die "Unknown option" if defined($reference) && $reference ne "--reference";
die "usage: capture.pl UPSTREAM OUTPUT DEMO (1..4)\n" unless $number && $number =~ /^[1-4]$/;
$root = File::Spec->rel2abs($root);
$out = File::Spec->rel2abs($out);
make_path($out);
open my $fh, '<', "$root/bin/frozen-bubble" or die $!;
my $src = do { local $/; <$fh> };
close $fh;
open my $log, '>', "$out/frames.jsonl" or die $!;
our (%demo_image, @demo_front, @demo_sound, $demo_drawing, $demo_back);
sub inject {
    my ($from, $to) = @_;
    my $count = $src =~ s/\Q$from\E/$to/g;
    die "Expected one upstream hook for $from, got " . ($count || 0) unless $count == 1;
}
inject('add_default_rect($img);', '$demo_image{$img} = substr($file, length("$FPATH/gfx/")); add_default_rect($img);');
inject('add_default_rect($canon{img}{$number});', '$demo_image{$replace} = "barrel/$number"; add_default_rect($canon{img}{$number});');
inject('add_default_rect($canon{img_mini}{$number});', '$demo_image{$replace2} = "mini-barrel/$number"; add_default_rect($canon{img_mini}{$number});');
inject('sub play_sound($) {', 'sub play_sound($) { push @demo_sound, $_[0] if $playdata;');
inject('sub put_image($$$) {', 'sub put_image($$$) { demo_sprite(\@demo_front, @_) if $demo_drawing;');
inject('sub put_image_to_background($$$) {', q!sub put_image_to_background($$$) {
    return if not($reference) && ($demo_image{$_[0]} || '') =~ m{^(?:balls/bubble-[0-9]+\.gif|on_top_next\.png)$};
!);
inject('    handle_graphics(\&put_image);' . "\n" . '    $frame++;', q{
    @demo_front = ();
    { local $demo_drawing = !$reference; handle_graphics(\&put_image); }
    if ($reference) {
        if ($recorddata{frame} == 1 || $recorddata{frame} == 500 || $recorddata{frame} == 950) {
            SDL::Video::save_BMP($app, "$out/reference-$recorddata{frame}.bmp");
        }
    } else { demo_frame(); }
    $frame++;
});
inject('    replay($replayparam);', '    $pdata{demo} = 1; replay($replayparam); exit 0;');
inject('    $to_wait > 0 and Games::FrozenBubble::CStuff::fbdelay($to_wait);' . "\n" . '    $saveframes and save_frame();', '');
inject('$FPATH = $Games::FrozenBubble::Config::FPATH;', '$FPATH = $root . "/share";');
my $helpers = <<'SOURCE';
sub demo_sprite {
    my ($list, $image, $x, $y) = @_;
    $image = translate_mini_image($image);
    my $name = $demo_image{$image} or die "Unknown sprite $image";
    if ($name =~ m{^(mini-)?barrel/(-?\d+)$}) {
        my $mini = $1; my $angle = $2;
        my $bounds = $canon{$mini ? 'data_mini' : 'data'}{$angle};
        # In the trace, the cannon anchor is the original rotation center.
        $x += ($mini ? 25 : 50) - $bounds->[0];
        $y += ($mini ? 25 : 50) - $bounds->[1];
        if ($mini && !-e "$out/cannon-$angle.rgba") {
            open my $raw, '>:raw', "$out/cannon-$angle.rgba" or die $!;
            print $raw pack('v4', $image->w, $image->h, $bounds->[0], $bounds->[1]);
            print $raw ${$image->get_pixels_ptr()}; close $raw;
        }
    }
    push @$list, [$name, int($x), int($y)];
}
sub demo_frame {
    my @board;
    iter_players {
        for my $b (@{$sticked_bubbles{$::p}}) {
            demo_sprite(\@board, $b->{img}, $b->{x}, $b->{y});
        }
        my $next = $next_bubble{$::p};
        if ($next && !$pdata{$::p}{chatting} && !$pdata{current_chat_messages}{$::p}) {
            demo_sprite(\@board, $next->{img}, $next->{x}, $next->{y});
            demo_sprite(\@board, $bubbles_anim{on_top_next},
                $next->{x} + $POS{$::p}{on_top_next_relpos}{x},
                $next->{y} + $POS{$::p}{on_top_next_relpos}{y});
        }
    };
    my $digest = md5_hex(${$background->get_pixels_ptr()});
    my $back = '';
    if (($demo_back || '') ne $digest) {
        $back = "$digest.bmp"; $demo_back = $digest;
        SDL::Video::save_BMP($background, "$out/$back") == 0 or die "save backdrop: " . SDL::get_error();
    }
    print $log encode_json([$recorddata{frame}, $back, \@board, \@demo_front, \@demo_sound]), "\n";
    @demo_sound = ();
}
SOURCE
inject('#- ----------- main -------------------------------------------------------', $helpers);
@ARGV = ('--no-sound', '--replay', "$root/share/data/demo$number.bz2");
$ENV{SDL_VIDEODRIVER} = $ENV{SDL_AUDIODRIVER} = 'dummy';
{ no warnings; eval $src; }
die $@ if $@;
