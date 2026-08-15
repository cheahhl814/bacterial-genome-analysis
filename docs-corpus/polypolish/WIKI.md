# Polypolish Wiki

Combined documentation from the [Polypolish wiki](https://github.com/rrwick/Polypolish/wiki) (cloned from `https://github.com/rrwick/Polypolish.wiki.git`), covering the Home, Software requirements, Installation, How to run Polypolish, Toy example, Alignment trimming, Insert size filter, Manual inspection of results, Local realignment, and FAQ pages.

---

## Contents

1. [Home](#home)
2. [Software requirements](#software-requirements)
3. [Installation](#installation)
4. [How to run Polypolish](#how-to-run-polypolish)
5. [Toy example](#toy-example)
6. [Alignment trimming](#alignment-trimming)
7. [Insert size filter](#insert-size-filter)
8. [Manual inspection of results](#manual-inspection-of-results)
9. [Local realignment](#local-realignment)
10. [FAQ and miscellaneous tips](#faq-and-miscellaneous-tips)

---

## Home

<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/logo_transparent.png" alt="Polypolish" width="70%"></p>

### The problem

While long-read sequencing platforms (like [Oxford Nanopore](https://nanoporetech.com/)) have gotten a lot better in recent years, long-read-only assemblies still suffer from some consensus sequence errors. Homopolymer-length errors are a common type, e.g. `AAAAAAAA` becoming `AAAAAAA`. One can use short reads (like from an [Illumina](https://www.illumina.com/) platform) to correct errors in a long-read assembly, a process known as short-read polishing. There are a number of short-read polishing tools, including [FMLRC2](https://github.com/HudsonAlpha/fmlrc2), [HyPo](https://github.com/kensung-lab/hypo), [NextPolish](https://github.com/Nextomics/NextPolish), [ntEdit](https://github.com/bcgsc/ntEdit), [Pilon](https://github.com/broadinstitute/pilon), [POLCA](https://github.com/alekseyzimin/masurca) and [Racon](https://github.com/lbcb-sci/racon).

However, errors in repeat sequences can be difficult to fix. Most of those short-read polishing tools rely on alignments generated from tools like [BWA-MEM](https://github.com/lh3/bwa). When run with default settings, aligners put each read in a single best location (randomly chosen in the case of a tie). So if the assembly has an error in a repeat, reads may not align to it because they can get a better alignment in other instances of the repeat. For example, consider a genome with a two-copy exact repeat (I'll call them copy A and copy B), and the assembly of this genome has an error in copy A. When aligning short reads to the assembly, all reads which originated from the error-containing region of copy A will instead align to the corresponding region of copy B, because they can achieve a more accurate alignment there. This leaves no reads aligned over the error, and a short-read polishing tool will therefore have no information with which to fix the error.

Long-read assemblies with short-read polishing can be very accurate, and their non-repeat sequences may in fact be perfect. But due to the scenario described above, errors often remain in repeat sequences. This problem keeps truly error-free genome assemblies out of reach.

### The solution

Polypolish is a short-read polishing tool that differs from existing tools in an important way: it uses short-read alignments where each read is aligned to _all_ possible locations. This means that errors in repeats will be covered by short-read alignments, and Polypolish can therefore fix those errors. For an illustrated walk-through of how it works, check out the [Toy example](#toy-example) page of this wiki.

In addition to its ability to polish repeats, Polypolish is very conservative: it only changes a locus when the evidence is very strong, otherwise opting to make no change. This means that Polypolish is very unlikely to introduce new errors into an assembly.

### Some caveats

No polishing tool is perfect, Polypolish included. This means that you should make your long-read assembly as accurate as possible _before_ doing any short-read polishing. [Autocycler](https://github.com/rrwick/Autocycler) can deliver clean assemblies which are free from medium-to-large scale errors.

Since different short-read polishers use different algorithms, I have found that using a combination of tools can deliver the most accurate assemblies. Aside from Polypolish, my favourite polisher is [pypolca](https://github.com/gbouras13/pypolca) – try using it in addition to Polypolish.

Nothing about Polypolish is intrinsically specific to bacterial genomes – its approach should work on eukaryotes too. However, I've only ever used it on bacterial genomes and small eukaryote genomes. Large repeat-rich eukaryote genomes might cause issues (see [this question in the FAQ](#does-polypolish-work-on-eukaryote-genomes)), so try at your own risk!

### Where to begin?

Check out the [Software requirements](#software-requirements) and [Installation](#installation) pages to get Polypolish up and running. Then the [How to run Polypolish](#how-to-run-polypolish) page will show you how to use it.

If you want to read more, here is the original Polypolish manuscript:<br>
[Wick RR, Holt KE. Polypolish: short-read polishing of long-read bacterial genome assemblies. PLOS Computational Biology. 2022. doi:10.1371/journal.pcbi.1009802.](https://doi.org/10.1371/journal.pcbi.1009802)

This follow-up manuscript describes Polypolish v0.6.0:<br>
[Bouras G, Judd LM, Edwards RA, Vreugde S, Stinear TP, Wick RR. How low can you go? Short-read polishing of Oxford Nanopore bacterial genome assemblies. Microbial Genomics. 2024. doi:10.1099/mgen.0.001254.](https://doi.org/10.1099/mgen.0.001254)

---

## Software requirements

Polypolish runs on macOS and Linux. It is coded in [Rust](https://www.rust-lang.org/), so you'll need to install Rust if you want to build Polypolish from source. However, many users can simply download pre-built binaries for their OS and will therefore not need Rust installed (see [Installation](#installation) for more detail).

### Aligner

Polypolish takes SAM files from the [BWA-MEM aligner](https://github.com/lh3/bwa) as input, so you will want to have that tool installed. Alternatively, you can use [minibwa](https://github.com/lh3/minibwa) which is the successor to BWA-MEM. [Bowtie 2](http://bowtie-bio.sourceforge.net/bowtie2/index.shtml) should also work, though I've tested it less. Other short-read aligners like [minimap2](https://github.com/lh3/minimap2) may work with Polypolish, but I haven't tested them myself. Read more about alternative aligners on the [FAQ and miscellaneous tips](#can-i-use-bwa-mem2-to-align-reads) page.

---

## Installation

### Installing from pre-built binaries

Polypolish compiles to a single executable binary (called `polypolish`), which makes installation easy!

Each [release of Polypolish](https://github.com/rrwick/Polypolish/releases) contains a pre-built binary for common operating systems (e.g. macOS, Ubuntu and CentOS). If you use one of these OSs, you can download the appropriate binary for your system and put the `polypolish` file in a directory that's in your `PATH` variable, e.g. `/usr/local/bin/` or `~/.local/bin/`.

Alternatively, you don't need to install Polypolish at all. Instead, you can just run it from wherever the `polypolish` executable happens to be, like this: `/some/path/to/polypolish --help`.

### Installing from source

There are a number of reasons why the pre-built binaries may not be ideal:
* you're using incompatible hardware or an unusual OS
* you want a version of Polypolish that doesn't correspond to a release (e.g. the latest commit)
* you want to modify the source code

If any of these apply to you, then you'll have to build Polypolish from source. [Install Rust](https://www.rust-lang.org/tools/install) if you don't already have it. Then clone and build Polypolish like this:
```bash
git clone https://github.com/rrwick/Polypolish.git
cd Polypolish
cargo build --release
```

You'll find the freshly built executable in `target/release/polypolish`, which you can then move to an appropriate location that's in your `PATH` variable.

### Installing with conda

Polypolish is also on [Bioconda](https://bioconda.github.io/recipes/polypolish/README.html).

To install polypolish in your currently active environment:
```bash
conda install -c conda-forge -c bioconda polypolish
```

To create a new conda environment for Polypolish:
```bash
conda create -c conda-forge -c bioconda -n polypolish polypolish
```

---

## How to run Polypolish

### Quick start (using BWA-MEM)

```bash
bwa index draft.fasta
bwa mem -t 16 -a draft.fasta reads_1.fastq.gz > alignments_1.sam
bwa mem -t 16 -a draft.fasta reads_2.fastq.gz > alignments_2.sam
polypolish filter --in1 alignments_1.sam --in2 alignments_2.sam --out1 filtered_1.sam --out2 filtered_2.sam
polypolish polish draft.fasta filtered_1.sam filtered_2.sam > polished.fasta
rm *.amb *.ann *.bwt *.pac *.sa *.sam
```

### Quick start (using minibwa)

```bash
minibwa index draft.fasta
minibwa map -t 16 -N 1000 --outn=1000 draft.fasta reads_1.fastq.gz > alignments_1.sam
minibwa map -t 16 -N 1000 --outn=1000 draft.fasta reads_2.fastq.gz > alignments_2.sam
polypolish filter --in1 alignments_1.sam --in2 alignments_2.sam --out1 filtered_1.sam --out2 filtered_2.sam
polypolish polish draft.fasta filtered_1.sam filtered_2.sam > polished.fasta
rm *.l2b *.mbw *.sam
```

### Using paired-end short reads

Most short-read sets are paired-end, so this will be the most common way to run Polypolish.

In these commands, I will assume your files are named like this:
* `draft.fasta`: the input assembly that you want to polish
* `reads_1.fastq.gz`: short reads (first in pair)
* `reads_2.fastq.gz`: short reads (second in pair)

The first step is to align the reads to your draft genome with BWA-MEM:
```bash
bwa index draft.fasta
bwa mem -t 16 -a draft.fasta reads_1.fastq.gz > alignments_1.sam
bwa mem -t 16 -a draft.fasta reads_2.fastq.gz > alignments_2.sam
```

Alternatively, you can use minibwa:
```bash
minibwa index draft.fasta
minibwa map -t 16 -N 1000 --outn=1000 draft.fasta reads_1.fastq.gz > alignments_1.sam
minibwa map -t 16 -N 1000 --outn=1000 draft.fasta reads_2.fastq.gz > alignments_2.sam
```

Important things to note here:
* It's important to align each read to _all_ possible locations, not just the best location. Polypolish needs this to polish repeat sequences. This is done with `-a` in the BWA-MEM command and `-N 1000 --outn=1000` in the minibwa command (1000 locations is not literally _all_ locations but good enough for a bacterial genome).
* You have to align the two read files separately. I.e. don't align both read files with a single command.
* I used `-t 16` in these commands to align using 16 threads. Adjust this value as is appropriate for your system. This will only affect the speed performance (the alignments themselves are unaffected by thread count).

You can then filter the alignments using [Polypolish's insert size filter](#insert-size-filter). This step is optional but recommended:
```bash
polypolish filter --in1 alignments_1.sam --in2 alignments_2.sam --out1 filtered_1.sam --out2 filtered_2.sam
```

Then give the draft genome and the alignments to Polypolish. It will output information to stderr and the polished assembly to stdout, so redirect its output to a file:
```bash
polypolish polish draft.fasta filtered_1.sam filtered_2.sam > polished.fasta
```

Finally, you can clean up the index files and alignments to save disk space:
```bash
rm *.amb *.ann *.bwt *.pac *.sa *.sam  # if using BWA-MEM
rm *.l2b *.mbw *.sam                   # if using minibwa
```

### Using other types of short reads

Polypolish works with one or more SAM files, so unpaired reads are easy:
```bash
bwa index draft.fasta
bwa mem -t 16 -a draft.fasta reads.fastq.gz > alignments.sam
polypolish polish draft.fasta alignments.sam > polished.fasta
rm *.amb *.ann *.bwt *.pac *.sa *.sam
```

And multiple paired-end read sets work too:
```bash
bwa index draft.fasta
bwa mem -t 16 -a draft.fasta reads_a_1.fastq.gz > alignments_a_1.sam
bwa mem -t 16 -a draft.fasta reads_a_2.fastq.gz > alignments_a_2.sam
bwa mem -t 16 -a draft.fasta reads_b_1.fastq.gz > alignments_b_1.sam
bwa mem -t 16 -a draft.fasta reads_b_2.fastq.gz > alignments_b_2.sam
polypolish filter --in1 alignments_a_1.sam --in2 alignments_a_2.sam --out1 filtered_a_1.sam --out2 filtered_a_2.sam
polypolish filter --in1 alignments_b_1.sam --in2 alignments_b_2.sam --out1 filtered_b_1.sam --out2 filtered_b_2.sam
polypolish polish draft.fasta filtered_*.sam > polished.fasta
```

### Careful mode

Polypolish is unlikely to introduce errors during polishing, but if you want to be _very_ sure that Polypolish doesn't introduce errors, use `--careful`:
```bash
polypolish polish --careful draft.fasta filtered_1.sam filtered_2.sam > polished.fasta
```

This will make Polypolish discard any read that aligns to multiple places. This effectively blinds Polypolish to repeat regions of the genome, which are at the highest risk of introduced errors. But it also means that Polypolish cannot fix any errors in repeat regions.

I recommend the use of `--careful` when read depth is low: 25× or less.

More info on careful mode and relevant benchmarks are available in [this paper](https://doi.org/10.1099/mgen.0.001254).

### Debug file

Polypolish has a `--debug` option which you can use to save per-base polishing information in a tab-delimited format. You can use it like this:
```bash
polypolish polish --debug polished.tsv draft.fasta filtered_1.sam filtered_2.sam > polished.fasta
```

The resulting file will have one line for each base of the assembly, so it will be hundreds of megabytes in size for a typical bacterial genome. See the [Toy example](#toy-example) page for an example of what this file looks like.

### Help text

If you run `polypolish --help`, you will see this top-level help message:
```
  _____        _                       _  _       _
 |  __ \      | |                     | |(_)     | |
 | |__) |___  | | _   _  _ __    ___  | | _  ___ | |__
 |  ___// _ \ | || | | || '_ \  / _ \ | || |/ __|| '_ \
 | |   | (_) || || |_| || |_) || (_) || || |\__ \| | | |
 |_|    \___/ |_| \__, || .__/  \___/ |_||_||___/|_| |_|
                   __/ || |
                  |___/ |_|

short-read polishing of long-read assemblies

Usage: polypolish <COMMAND>

Commands:
  filter  filter paired-end alignments based on insert size
  polish  polish a long-read assembly using short-read alignments

Options:
  -h, --help     Print help
  -V, --version  Print version
```

Run `polypolish filter --help` to see the help for the filter subcommand:
```
filter paired-end alignments based on insert size

Usage: polypolish filter [OPTIONS] --in1 <IN1> --in2 <IN2> --out1 <OUT1> --out2 <OUT2>

Options:
      --in1 <IN1>                  Input SAM file - first read in pairs
      --in2 <IN2>                  Input SAM file - second read in pairs
      --out1 <OUT1>                Output SAM file - first read in pairs
      --out2 <OUT2>                Output SAM file - second read in pairs
      --orientation <ORIENTATION>  Expected pair orientation [default: auto]
      --low <LOW>                  Low percentile threshold [default: 0.1]
      --high <HIGH>                High percentile threshold [default: 99.9]
  -h, --help                       Print help
  -V, --version                    Print version
```

And run `polypolish polish --help` to see the help for the polish subcommand:
```
polish a long-read assembly using short-read alignments

Usage: polypolish polish [OPTIONS] <ASSEMBLY> <SAM>...

Arguments:
  <ASSEMBLY>  Assembly to polish (one file in FASTA format)
  <SAM>...    Short read alignments (one or more files in SAM format)

Options:
      --debug <DEBUG>                        Optional file to store per-base information for debugging purposes
  -i, --fraction_invalid <FRACTION_INVALID>  A base must make up less than this fraction of the read depth to be
                                             considered invalid [default: 0.2]
  -v, --fraction_valid <FRACTION_VALID>      A base must make up at least this fraction of the read depth to be
                                             considered valid [default: 0.5]
  -m, --max_errors <MAX_ERRORS>              Ignore alignments with more than this many mismatches and indels
                                             [default: 10]
  -d, --min_depth <MIN_DEPTH>                A base must occur at least this many times in the pileup to be
                                             considered valid [default: 5]
      --careful                              Ignore any reads with multiple alignments
  -h, --help                                 Print help
  -V, --version                              Print version
```

---

## Toy example

This page will show how Polypolish works using a small and simple example. The genome in this example is only 100-bp long and has a 20-bp two-copy repeat:
<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/toy_example/reference.png" alt="reference" width="90%"></p>

Here is the assembly which contains three errors (that we aim to fix):
<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/toy_example/draft.png" alt="assembly" width="90%"></p>

And here are the error-free short reads which we will use to polish the assembly:
<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/toy_example/reads.png" alt="reads" width="90%"></p>

While this example is tiny, it can still be run in Polypolish, so download the files here if you want to try for yourself: [`assembly.fasta`](https://github.com/rrwick/Polypolish/wiki/files/toy_example/assembly.fasta), [`reads.fastq`](https://github.com/rrwick/Polypolish/wiki/files/toy_example/reads.fastq), [`alignments.sam`](https://github.com/rrwick/Polypolish/wiki/files/toy_example/alignments.sam)

### Read alignment

#### One alignment per read (the wrong way)

Aligning reads in the normal way (i.e. using default aligner settings) involves putting each read in its single best position. If there are multiple equally good positions, then one is chosen at random. This would result in alignments that look like this:
<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/toy_example/alignments_one.png" alt="read alignments (one per read)" width="90%"></p>

This illustrates the problem with that alignment strategy: the error in the first copy of the repeat has caused reads from that part of the genome to align to the second copy of the repeat. This has left no reads aligning over the error.

#### All alignments (the right way)

If we instead align each read to _all_ possible locations, we get alignments that look like this:
<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/toy_example/alignments_all.png" alt="read alignments (all per read)" width="90%"></p>

I've coloured the reads which align to multiple locations in red. Now we have reads aligning over the error in the repeat, and these are the kind of alignments that Polypolish was built to take.

### Building a pileup

Using an all-alignments input, Polypolish tallies up the read sequences at each position of the assembly to make a pileup. You can visualise the process as taking the alignment (drawn above) and squashing down each column to remove the empty space:

<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/toy_example/pileup.png" alt="pileup" width="90%"></p>

Some things to note:
* Each base of the assembly usually corresponds to a single base from the reads. However, a deletion in the reads relative to the assembly results in no base (shown as `-`) and an insertion in the reads relative to the assembly results in multiple bases at one position (a squished `CT` in this example).
* The shaded green area represents the read depth at each position of the assembly. In non-repetitive regions (where reads align to only one position), the read depth is equivalent to the number of alignments. But for repetitive regions, the read depth is less than the number of alignments. This is because reads with multiple alignments only contribute fractional depth to each of their locations. E.g. when a read aligns to two possible places, it adds 0.5 depth to each of those places.
* The dotted red lines represent the threshold depths (used in the next step and explained more there). For the invalid threshold depth (bottom dotted red line), Polypolish sets this to 20% of the read depth (adjustable with `--fraction_invalid`) with a minimum value of 1. For the valid threshold depth (top dotted red line), Polypolish sets this to either 5 (adjustable with `--min_depth`) or half the read depth (adjustable with `--fraction_valid`), whichever is larger. This toy example has low read depth, so the valid threshold depth is the minimum (5) for many positions of the assembly. In a real situation (with higher read depth), the valid threshold depth would be half the read depth for most positions of the assembly.
* You might notice that the pileup seems to be missing some sequences which were in the alignment. E.g. a few reads aligned all the way to the end of the assembly, but in the pileup there are two bases at the end with no sequence. This is due to Polypolish's [alignment trimming](#alignment-trimming) logic.

### Fixing errors

Polypolish will assess these conditions for each position in the pileup:
1. All sequences are either valid (greater than or equal to the valid threshold depth) or invalid (less than the invalid threshold depth). I.e. none of the sequences fall in between those two thresholds which would indicate ambiguous validity.
2. There is one and only one valid sequence. A valid sequence is defined as a sequence in the pileup which occurs at least as many times as the valid threshold depth (controlled by `--min_depth` and `--fraction_valid`).
3. The read depth is sufficiently high (controlled by `--min_depth`).
4. The one valid sequence differs from the assembly base.

The possible outcomes are:
* If all four conditions are true, that indicates an error in need of repair. Polypolish will change that base of the assembly to the pileup's valid sequence.
* If conditions 1–3 are true but condition 4 is false, that simply means that the pileup agrees with the assembly's base and no change is needed. This should be the most common outcome.
* If any of conditions 1–3 are false, then something is unclear about this position: no valid sequence, multiple valid sequences, one or more ambiguously valid sequences, or low read depth. Polypolish plays it safe and does not make a change.

In our example, repairs occur at three positions:
<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/toy_example/fixes.png" alt="fixes" width="90%"></p>

These changes correspond to the three errors in the assembly, so the resulting genome is error free!

Since Polypolish only makes a change in unambiguous cases, it is unlikely to _introduce_ an error into the assembly genome. So you can be reasonably sure that the output of Polypolish is at least no worse than the input. It is a 'do no harm' polishing strategy (credit to [this paper](https://www.biorxiv.org/content/10.1101/2021.07.02.450803v1) for that term).

### Debug output

If you are interested in per-base polishing information, you can use Polypolish's `--debug` option to save a tab-delimited table to file. For each position of the assembly, you can see the assembly base, depth, threshold depth, read sequence pileup, status and new base.

The status can be:
* `low_depth`: depth is below `--min_depth`
* `none`: no valid options
* `multiple`: more than one valid option
* `too_close`: one or more options are neither valid nor invalid
* `kept`: one valid option which matches the assembly base
* `changed`: one valid option which differs from the assembly base

Here is what this file looks like for our toy example:
```
name   pos  base  depth  invalid  valid  pileup        status     new_base
draft  0    G     1.0    1        5      Gx1           low_depth  G
draft  1    A     2.0    1        5      Ax2           low_depth  A
draft  2    C     2.0    1        5      Cx2           low_depth  C
draft  3    T     2.0    1        5      Tx2           low_depth  T
draft  4    G     3.0    1        5      Gx3           low_depth  G
draft  5    T     4.0    1        5      Tx4           low_depth  T
draft  6    T     4.0    1        5      Tx4           low_depth  T
draft  7    C     4.0    1        5      Cx4           low_depth  C
draft  8    A     5.0    1        5      Ax5           kept       A
draft  9    A     5.0    1        5      Ax5           kept       A
draft  10   C     6.0    1        5      Cx6           kept       C
draft  11   G     9.0    2        5      Gx9           kept       G
draft  12   C     11.0   2        6      Cx11          kept       C
draft  13   G     11.0   2        6      Gx11          kept       G
draft  14   A     12.0   2        6      Ax13          kept       A
draft  15   T     11.5   2        6      Tx13          kept       T
draft  16   C     10.5   2        5      -x2,Cx10      too_close  C
draft  17   G     11.5   2        6      -x2,Gx11,Tx2  too_close  G
draft  18   C     12.5   2        6      Cx18          kept       C
draft  19   T     10.0   2        5      Tx16          kept       T
draft  20   G     7.5    2        5      Gx14          kept       G
draft  21   T     7.5    2        5      Tx15          kept       T
draft  22   A     7.0    1        5      Ax14          kept       A
draft  23   T     8.0    2        5      Tx16          kept       T
draft  24   T     8.5    2        5      Tx17          kept       T
draft  25   C     7.5    2        5      Cx15          kept       C
draft  26   A     10.5   2        5      Ax21          kept       A
draft  27   G     9.5    2        5      Cx19          changed    C
draft  28   C     9.0    2        5      Cx18          kept       C
draft  29   A     9.5    2        5      Ax19          kept       A
draft  30   A     10.0   2        5      Ax20          kept       A
draft  31   G     11.0   2        6      Gx22          kept       G
draft  32   G     9.5    2        5      Gx18          kept       G
draft  33   T     12.5   2        6      Tx21          kept       T
draft  34   T     9.0    2        5      Tx14          kept       T
draft  35   C     7.0    1        5      Cx10          kept       C
draft  36   T     9.0    2        5      Tx12          kept       T
draft  37   T     9.5    2        5      Tx11          kept       T
draft  38   C     10.0   2        5      Cx10          kept       C
draft  39   G     11.0   2        6      Gx11          kept       G
draft  40   G     10.0   2        5      Gx10          kept       G
draft  41   C     11.0   2        6      Cx11          kept       C
draft  42   C     14.0   3        7      Cx14          kept       C
draft  43   T     14.0   3        7      Tx14          kept       T
draft  44   T     12.0   2        6      Tx12          kept       T
draft  45   C     12.0   2        6      Cx12          kept       C
draft  46   A     10.0   2        5      Ax10          kept       A
draft  47   C     9.0    2        5      Cx9           kept       C
draft  48   G     6.0    1        5      Gx6           kept       G
draft  49   T     7.0    1        5      Tx7           kept       T
draft  50   A     4.0    1        5      Ax4           low_depth  A
draft  51   C     6.0    1        5      CTx6          changed    CT
draft  52   C     5.0    1        5      Cx5           kept       C
draft  53   T     5.0    1        5      Tx5           kept       T
draft  54   G     6.0    1        5      Gx6           kept       G
draft  55   C     8.0    2        5      Cx8           kept       C
draft  56   G     7.0    1        5      Gx7           kept       G
draft  57   C     7.0    1        5      Cx7           kept       C
draft  58   T     5.5    1        5      Tx6           kept       T
draft  59   A     6.5    1        5      Ax7,Cx1       too_close  A
draft  60   T     7.5    2        5      Gx3,Tx8       too_close  T
draft  61   C     9.5    2        5      Cx15          kept       C
draft  62   T     9.0    2        5      Tx15          kept       T
draft  63   G     7.5    2        5      Gx14          kept       G
draft  64   T     7.5    2        5      Tx15          kept       T
draft  65   A     8.0    2        5      Ax15          kept       A
draft  66   T     9.0    2        5      Tx17          kept       T
draft  67   T     9.5    2        5      Tx18          kept       T
draft  68   C     8.5    2        5      Cx16          kept       C
draft  69   A     9.5    2        5      Ax18          kept       A
draft  70   C     10.5   2        5      Cx20          kept       C
draft  71   C     10.0   2        5      Cx19          kept       C
draft  72   A     10.5   2        5      Ax20          kept       A
draft  73   A     10.0   2        5      Ax20          kept       A
draft  74   G     11.0   2        6      Gx22          kept       G
draft  75   G     9.5    2        5      Gx18          kept       G
draft  76   T     11.5   2        6      Tx20          kept       T
draft  77   T     11.0   2        6      Tx16          kept       T
draft  78   C     10.0   2        5      Cx13          kept       C
draft  79   T     11.0   2        6      Tx14          kept       T
draft  80   T     11.0   2        6      Tx13          kept       T
draft  81   A     9.5    2        5      Ax10          kept       A
draft  82   A     9.0    2        5      Ax9           kept       A
draft  83   C     9.0    2        5      Cx9           kept       C
draft  84   T     10.0   2        5      Tx10          kept       T
draft  85   A     8.0    2        5      -x8           changed    -
draft  86   C     5.0    1        5      Cx5           kept       C
draft  87   G     5.0    1        5      Gx5           kept       G
draft  88   T     4.0    1        5      Tx4           low_depth  T
draft  89   G     3.0    1        5      Gx3           low_depth  G
draft  90   T     7.0    1        5      Tx7           kept       T
draft  91   G     7.0    1        5      Gx7           kept       G
draft  92   G     6.0    1        5      Gx6           kept       G
draft  93   A     5.0    1        5      Ax5           kept       A
draft  94   G     5.0    1        5      Gx5           kept       G
draft  95   C     4.0    1        5      Cx4           low_depth  C
draft  96   T     4.0    1        5      Tx4           low_depth  T
draft  97   G     4.0    1        5      Gx4           low_depth  G
draft  98   C     0.0    1        5                    low_depth  C
draft  99   G     0.0    1        5                    low_depth  G
```

---

## Alignment trimming

Homopolymer-length errors are the most common type of error in long-read-only assemblies, and so Polypolish contains a little bit of extra logic to help with these: some bases are trimmed off the ends of alignments before generating the pileup. This page uses a small example to illustrate how and why this works.

Here is the reference genome in this example, with an 8×T homopolymer in the middle:
<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/alignment_trimming/reference.png" alt="reference" width="90%"></p>

And here is the assembly which contains a deletion, turning the homopolymer into 7×T:
<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/alignment_trimming/draft.png" alt="assembly" width="90%"></p>

Polypolish aims to use short reads (which contain the correct 8×T homopolymer) to repair that deletion.

Note that the deletion could be considered to occur anywhere in that homopolymer sequence – deleting any one of the 8 Ts would yield the same result. But since aligners tend to left-align indels (i.e. put indels in their leftmost position), it is appropriate to consider the deletion occurring on the left side of the homopolymer.

### Without alignment trimming

Aligning short reads to the assembly yields the following alignments (with the relevant position highlighted in yellow):
<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/alignment_trimming/alignments_no_trimming.png" alt="alignments without trimming" width="90%"></p>

You can see that some of the alignments have done the correct thing by inserting an extra T (A → AT) at the relevant position. However, many alignments have not. Specifically, reads that end in the homopolymer do not need an insertion to align cleanly.

This ambiguity (some alignments support an insertion and some don't) is reflected in the pileup:

<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/alignment_trimming/pileup_no_trimming.png" alt="pileup without trimming" width="90%"></p>

At the relevant position, the pileup contains 8 votes for A, 8 votes for AT and 1 vote for T. So Polypolish would not be able to make a decision here, and the deletion error would remain unfixed.

### With alignment trimming

To solve this problem, Polypolish trims a few bases off the end of the alignments. Specifically, it does the following:
* Whatever base is at the end of the alignment is trimmed off, however many times it occurs. So if an alignment ends in GGG, all three Gs are trimmed.
* One more additional base is trimmed off.

Or if you prefer the logic in Python:
```python
last_base = aligned_bases[-1]
while aligned_bases[-1] == last_base:
    aligned_bases.pop()
aligned_bases.pop()
```

After applying this logic, the alignments look like this (trimmed bases shown faintly):

<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/alignment_trimming/alignments_with_trimming.png" alt="alignments with trimming" width="90%"></p>

And the pileup looks like this:

<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/alignment_trimming/pileup_with_trimming.png" alt="pileup with trimming" width="90%"></p>

At the relevant position, the pileup now contains 8 votes for AT and 1 vote for T. So Polypolish will change the sequence to AT, repairing the error.

---

## Insert size filter

Before running `polypolish polish`, you can (and probably should) run `polypolish filter` to exclude some alignments based on their insert size. This should reduce the number of excessive alignments, particularly near the edges of repeat sequences, improving Polypolish's ability to fix errors in those regions.

### The goal

Insert-size filtering aims to use read pairing to remove spurious alignments, i.e. alignments of a read to the wrong instance of a repeat.

Consider this toy example, where read A-1 aligns to three locations (because it's in a repeat) and read A-2 (its pair) aligns to only one location:

<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/insert_size_filter/insert_size_filter_before.png" alt="insert size filter (before)" width="80%"></p>

Based on our expectations of paired-end orientation and insert size, we can assume that the first alignment and last alignment for read A-1 are spurious, and only the middle one should be kept:

<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/insert_size_filter/insert_size_filter_after.png" alt="insert size filter (after)" width="80%"></p>

### How it works

The first thing `polypolish filter` does is figure out the insert size distribution for the read set. It does this by looking exclusively at read pairs which have exactly one alignment per read. It will also automatically determine the [read orientation](https://gatk.broadinstitute.org/hc/en-us/articles/360035531792-Paired-end-or-mate-pair) (typically FR for paired-end reads) if it wasn't specified with the `--orientation` option. `polypolish filter` then sets a low threshold and a high threshold using the insert size distribution. These will be the 0.1st and 99.9th percentiles by default but can be adjusted with the `--low` and `--high` options. These thresholds now define what a 'good' insert size looks like: greater than or equal to the low threshold and less than or equal to the high threshold.

The filter automatically recognises three read-name styles: identical names in both files, `/1` and `/2` suffixes, or `.1` and `.2` suffixes. It will quit with an error if no reads pair up, or print a warning if fewer than half of the reads in either file have a matching pair.

`polypolish filter` then assesses each alignment using this logic:
* If there are no pair alignments, it passes. I.e. if `polypolish filter` can't use read pairs to assess the alignment, it is kept.
* If there is exactly one alignment for this read, it passes. I.e. `polypolish filter` is not going to throw out the only alignment for a read.
* If there are multiple alignments for this read and at least one pair alignment, then the alignment passes if and only if it fits (good insert size and correct orientation) with any of the pair alignments.

Alignments that pass the filter are written unchanged to the output SAM file. Alignments that fail the filter are written with a `ZP:Z:fail` [tag](https://samtools.github.io/hts-specs/SAMtags.pdf). Polypolish will then know to ignore these alignments in its algorithm. Incidentally, you can use this tag yourself if you want to write other alignment filters to run before Polypolish.

You might wonder why `polypolish filter` doesn't simply exclude failed alignments from the output file. This is because SAM files from BWA only contain sequence for one alignment per read (the rest use `*` to save space), so excluding alignments could lead to reads without sequence in the output SAM file, which would cause Polypolish to crash.

### Benefit

<p align="center"><img src="https://github.com/rrwick/Polypolish/wiki/images/insert_size_filter/polypolish_v0.4.3_vs_v0.5.0.png" alt="Polish v0.4.3 vs v0.5.0" width="100%"></p>

This figure compares Polypolish v0.4.3 (no insert size alignment filter) with Polypolish v0.5.0 (with insert size alignment filter) using the data from the [Polypolish manuscript](https://doi.org/10.1101/2021.10.14.464465). Results are shown for Polypolish alone and Polypolish+POLCA (the combination recommended in the manuscript) using both simulated reads **(A)** and real reads **(B)**, following the same methods used in the manuscript.

The difference is small but positive: for every assembly, Polypolish v0.5.0 produced an equivalent or more accurate sequence than Polypolish v0.4.3.

### Mate-pair read sets

I haven't yet tried `polypolish filter` with [mate-pair](https://sapac.illumina.com/science/technology/next-generation-sequencing/mate-pair-sequencing.html) read sets, because these are uncommon for bacterial genomes. However, insert-size filtering should work especially well with mate-pair reads. A large insert size increases the chance that at least one read in each pair has a unique alignment (i.e. decreases the chance that both reads in a pair fall in a repeat). Since mate-pair libraries can have multi-kilobase insert sizes, they should provide a lot of alignment-culling power to `polypolish filter`.

---

## Manual inspection of results

The [`compare_assemblies.py`](https://github.com/rrwick/Perfect-bacterial-genome-tutorial/blob/main/scripts/compare_assemblies.py) script can help you to manually inspect polishing results.

It takes two assemblies (e.g. pre-polishing and post-polishing) as input, aligns them and then produces a human-readable output showing regions of the alignment where there are differences. It can compare any two assemblies (i.e. they don't have to be pre/post Polypolish) as long as the two assemblies have the same contigs in the same order.

Requirements, installation instructions and usage are available here:<br>
[github.com/rrwick/Perfect-bacterial-genome-tutorial/wiki/Comparing-assemblies](https://github.com/rrwick/Perfect-bacterial-genome-tutorial/wiki/Comparing-assemblies)

### Sample output

```
before_polishing 1193-1222: GGTTTGTAGCAAAAA-CTAAGCCCACCAAGA
 after_polishing 1193-1223: GGTTTGTAGCAAAAAACTAAGCCCACCAAGA
                                           *

before_polishing 1247-1276: TTTTTTATTCAAAAA-GAAAGCCCTCTTCAA
 after_polishing 1248-1278: TTTTTTATTCAAAAAAGAAAGCCCTCTTCAA
                                           *

before_polishing 1650-1679: AATAAAGTCTTTTTT-GTTCTCTCTATTAAA
 after_polishing 1652-1682: AATAAAGTCTTTTTTTGTTCTCTCTATTAAA
                                           *

before_polishing 1733-1979: AAAGTACGAAGGATTTTATTCTGCATAAGATCATGATTGACCATGTTTAGGATGGAAGATGACAGAGTCATATGTAAACAAAGAAGAAATCATCTCTTTAGCAAAGAATGCTGCATTGGAGTTGGAAGATGCCCACGTGGAAGAGTTCGTAACATCTATGAATGACGTCATTGCTTTAATGCAGGAAGTAATCGCGATAGATATTTCGGATATCATTCTTGAAGCTACAGTGCATCATTTCGTTGGT
 after_polishing 1736-1828: AAAGTACGAAGGATT--ATT--GC-T----T--T-A---A---TG-----------------CAG-G--A-A-GTAA------------TC---------GC---GA-T-----A--G-A-T---A---T-------T-------T-CG----------GA-T-A--TCATT-CTT----G--A--A-G----C----TA-------C--A----------G----T---G--CATCATTTCGTTGGT
                                           **   **  * **** ** * *** ***  *****************   * ** * *    ************  *********  ***  * ***** ** * * *** *** ******* ******* *  **********  * * **     *   **** * ** * **** ****  ******* ** ********** **** *** **

before_polishing 3787-3816: TGCGCTGTAGAGGGG-ATGTCGCTTTATTTA
 after_polishing 3635-3665: TGCGCTGTAGAGGGGGATGTCGCTTTATTTA
                                           *

before_polishing 6434-6463: AGAGGAGGAACGGGG-AGCTTGGCAGCCGCT
 after_polishing 6284-6314: AGAGGAGGAACGGGGGAGCTTGGCAGCCGCT
                                           *
```

As you can see, most of the regions of difference in this example are single changes in homopolymer length – exactly the sort of change one would expect to see after polishing a long-read assembly with short reads.

However, one region (position 1733-1979 in the before-polishing sequence) contains far more differences. This could indicate that the before-polishing sequence was poorly assembled in that region, or maybe that something has gone wrong with the polishing. E.g. maybe the long reads used to generate the assembly and the short reads used to polish disagree at that locus. Either way, it's a region of interest and the sort of thing this human-readable file can help you to identify.

---

## Local realignment

Polypolish does _not_ perform local realignment. However, the concept is relevant and I thought it deserved a wiki page. So if you're interested, read on...

### What is local realignment?

Most read alignment strategies align each read independently. I.e. a read's alignment doesn't depend on other reads in the read set. However, there can often be multiple ways of aligning reads around indels, and some alignments will make the 'wrong' choice. This is especially common when an indel is near the end of a read.

For example, consider these alignments, where there is a 4-bp deletion in the reads relative to the reference:
```
   read 5:                                 GTGCGTGTGCGAGGAACCTT
   read 4:                          TACG----TGCGTGTGCGAGGAAC
   read 3:                     GCGACTACG----TGCGTGTGCGA
   read 2:               TACTGTGCGACTACG----TGCGT
   read 1:           CTTTTACTGTGCGACTACGT
           ——————————————————————————————————————————————————————————————
reference: AATTCGTGGACTTTTACTGTGCGACTACGACCATGCGTGTGCGAGGAACCTTAGACTGTCAG
```

Reads 1 and 5 didn't get the alignment quite right, because due to the scoring scheme, a 1-bp mismatch was preferable to a 4-bp deletion. When looking at just read 1 or just read 5, their alignment looks good. It's only when looking at _all_ read alignments together that it becomes clear that there's a 4-bp deletion and reads 1 and 5 could be aligned better.

Local realignment adjusts read alignments by taking each other into account. In our example, this should yield the following, where reads 1 and 5 are in agreement with the rest:
```
   read 5:                             G----TGCGTGTGCGAGGAACCTT
   read 4:                          TACG----TGCGTGTGCGAGGAAC
   read 3:                     GCGACTACG----TGCGTGTGCGA
   read 2:               TACTGTGCGACTACG----TGCGT
   read 1:           CTTTTACTGTGCGACTACG----T
           ——————————————————————————————————————————————————————————————
reference: AATTCGTGGACTTTTACTGTGCGACTACGACCATGCGTGTGCGAGGAACCTTAGACTGTCAG
```

Note that the words 'local' and 'realignment' can have different meanings in different contexts, so the term 'local realignment' might be a bit confusing:
* Usually in the context of alignment, 'local' means not 'global' (e.g. Smith-Waterman vs Needleman-Wunsch). But in 'local realignment', 'local' refers to the fact that the realignment only aims to make small changes to each read's alignment in the same vicinity of the reference (i.e. locally).
* 'Realignment' can also refer to the act of taking reads aligned to one reference genome and adjusting the alignments to a different reference genome. E.g. human short reads might be aligned to GRCh37 but you need them to be aligned to GRCh38. This is a different kind of 'realignment' and not what we're talking about here.

You can read more about local realignment in these papers:
* [Improved variant discovery through local re-alignment of short-read next-generation sequencing data using SRMA](https://genomebiology.biomedcentral.com/articles/10.1186/gb-2010-11-10-r99)
* [A framework for variation discovery and genotyping using next-generation DNA sequencing data](https://www.nature.com/articles/ng.806)

### Local realignment before Polypolish?

Since Polypolish uses the read pileup to call variants, including indels, local realignment could be beneficial. So if you can locally realign your alignments prior to giving those alignments to Polypolish, you should do so!

However, I have found it to be very difficult in practice. [GATK v3 could do local realignment](https://github.com/broadinstitute/gatk-docs/blob/master/gatk3-tutorials/(howto)_Perform_local_realignment_around_indels.md), but [this was removed from GATK in v4](https://github.com/broadinstitute/gatk-docs/blob/master/blog-2012-to-2019/2016-06-21-Changing_workflows_around_calling_SNPs_and_indels.md). Even if you're willing to use an old version of GATK, there are a lot of roadblocks along the way - it's not an easy process! [SRMA](https://sourceforge.net/projects/srma/) doesn't support the all-per-read alignments that Polypolish needs (it outputs only one alignment per read). CLC Genomics Workbench [seems to have a tool for local realignment](http://resources.qiagenbioinformatics.com/manuals/clcgenomicsworkbench/700/index.php?manual=Local_realignment.html), but it isn't open source so I haven't been able to try it. And some other tools like [glia](https://github.com/ekg/glia) only realign around specific variants in a VCF - not the entire set of alignments. Samtools/Bcftools avoid local realignment, instead relying on their [BAQ system](https://academic.oup.com/bioinformatics/article/27/8/1157/227268) to address the problem in a different way.

Since I can't find a good way to do it, I don't use local realignment before running Polypolish. But if there is a method that I've missed, I would love to hear about it! So if you know of one, please send me an email.

---

## FAQ and miscellaneous tips

### Table of contents

* [Polypolish performance](#polypolish-performance)
* [Adjusting Polypolish options](#adjusting-polypolish-options)
* [Does Polypolish work on eukaryote genomes?](#does-polypolish-work-on-eukaryote-genomes)
* [Does Polypolish work on metagenomes?](#does-polypolish-work-on-metagenomes)
* [Can I align my paired-end reads in a single BWA-MEM command?](#can-i-align-my-paired-end-reads-in-a-single-bwa-mem-command)
* [Does the order of alignments in the SAM file matter?](#does-the-order-of-alignments-in-the-sam-file-matter)
* [Can I use Bwa-mem2 to align reads?](#can-i-use-bwa-mem2-to-align-reads)
* [Can I use Bowtie2 to align reads?](#can-i-use-bowtie2-to-align-reads)
* [Can I use BBMap to align reads?](#can-i-use-bbmap-to-align-reads)
* [Should I run multiple rounds of Polypolish polishing?](#should-i-run-multiple-rounds-of-polypolish-polishing)
* [Why does Polypolish only use end-to-end alignments?](#why-does-polypolish-only-use-end-to-end-alignments)
* [Can Polypolish add/remove bases at the start/end of a sequence?](#can-polypolish-addremove-bases-at-the-startend-of-a-sequence)
* [Does Polypolish change contig names?](#does-polypolish-change-contig-names)
* [Why are `polypolish filter` and `polypolish polish` separate?](#why-are-polypolish-filter-and-polypolish-polish-separate)
* [Saving Polypolish's log to file](#saving-polypolishs-log-to-file)

<br>

### Polypolish performance

Polypolish is quick and efficient, at least on the bacterial genomes I've tested it on:
* A small and simple bacterial genome should take less than a minute to polish and use less than a gigabyte of RAM.
* A big or complex (i.e. repeat rich) bacterial genome can take a few minutes to polish and use a few gigabytes of RAM.

Polypolish itself is single-threaded, but aligners parallelise well, so use as many threads as you have available when preparing the alignments for Polypolish.

<br>

### Adjusting Polypolish options

Polypolish is designed to be conservative in its error correction, i.e. it only corrects errors when there is strong evidence to do so. This means it is more likely to suffer from false negatives (failing to correct an error) than false positives (introducing an error).

Polypolish's default options are:
```
--min_depth 5 --fraction_invalid 0.2 --fraction_valid 0.5
```

If you want Polypolish to be less conservative (i.e. more willing to fix errors but with an increased risk of introducing errors), you could use these options:
```
--min_depth 3 --fraction_invalid 0.3 --fraction_valid 0.4
```

If you want Polypolish to be more conservative (i.e. only fixing errors when the evidence is _very_ strong), you could use these options:
```
--min_depth 15 --fraction_invalid 0.1 --fraction_valid 0.6 --careful
```

See the [Toy example](#toy-example) page for a deeper explanation of how these options work.

<br>

### Does Polypolish work on eukaryote genomes?

Polypolish was designed with bacterial genomes in mind, but it should also work on small haploid eukaryote genomes. It's probably not appropriate for large and/or diploid eukaryote genomes. Nothing about Polypolish's algorithm is in principle tuned to bacterial genomes. However, Polypolish requires that you align each short read to all possible locations, and for a repeat-rich eukaryote genome, this could result in a _lot_ of alignments. So there may be practical limitations.

To illustrate the problem, consider two bacterial genomes I have used with Polypolish: [_Bacillus subtilis_ NC_000964.3](https://www.ncbi.nlm.nih.gov/nuccore/NC_000964.3) and [_Bordetella pertussis_ NC_002929.2](https://www.ncbi.nlm.nih.gov/nuccore/NC_002929.2). About 2% of the _Bacillus_ genome is repetitive, and my 1.4 million reads for that genome result in 1.6 million alignments. Most reads only align to a single place, so there aren't that many more alignments than reads. The _Bordetella_ genome is a similar size, but it is 9% repetitive due to hundreds of copies of IS<em>481</em>. For that genome, 1.4 million reads result in a whopping 13.6 million alignments! Eukaryote genomes can be 50% or more repetitive, so I shudder to think how many alignments they might generate.

I've successfully tried Polypolish on a _Drosophila_ genome, but it was pretty slow (took ~6 hours). If you try it on a bigger genome, let me know how well (or not well) it worked.

Also, Richard Wheeler wrote a tool named [polyalign](https://github.com/zephyris/polyalign) which may help with some of Polypolish's memory usage problems with eukaryote genomes (see [issue #25](https://github.com/rrwick/Polypolish/issues/25)).

<br>

### Does Polypolish work on metagenomes?

Short answer: probably! While designed with isolates in mind, Polypolish is conservative (unlikely to introduce errors) and should for the most part work well on long-read metagenome assemblies too.

I can, however, think of one particular case where Polypolish could introduce an error into a metagenome: when you've got a very similar sequence shared between a high-depth genome and a low-depth genome. E.g. genome A has 2000× read depth and genome B has 20× read depth, and both share some sequence at high identity. In that case, there's a risk that Polypolish could change the shared sequence in genome B to look like the shared sequence in genome A. For this reason, I recommend using the `--careful` option when polishing a metagenome.

It's also worth pointing out that Polypolish was made with _completed_ genome assemblies in mind: its input should ideally be one-contig-per-replicon. Some metagenome assemblies get pretty messy, especially when you have a mixture of closely-related genomes. I don't know how well Polypolish would perform on a highly-fragmented metagenome assembly, so interpret any results with caution.

<br>

### Can I align my paired-end reads in a single BWA-MEM command?

The [How to run Polypolish](#how-to-run-polypolish) page instructs you to align paired-end reads into separate SAM files like this:
```bash
bwa mem -t 16 -a draft.fasta reads_1.fastq.gz > alignments_1.sam
bwa mem -t 16 -a draft.fasta reads_2.fastq.gz > alignments_2.sam
```

You might be tempted to combine those into a single command:
```bash
bwa mem -t 16 -a draft.fasta reads_1.fastq.gz reads_2.fastq.gz > alignments.sam
```
**DON'T DO THIS!** While that BWA-MEM command will run successfully, it will _not_ make a SAM file appropriate for use with Polypolish. BWA-MEM's `-a` option (which Polypolish relies on to polish repeat regions) has no effect when used on paired read files, so the combined command will only have a single alignment for each read.

<br>

### Does the order of alignments in the SAM file matter?

The order of the SAM alignments will not change Polypolish's output (the polished genome sequence) but it can affect whether or not Polypolish will successfully run.

Polypolish assumes that all of the alignments for each read are grouped together on adjacent lines in the SAM file. This is how BWA-MEM outputs its SAM files, so it shouldn't be a problem. But if you've sorted your alignments using `samtools sort`, they may not work with Polypolish.

When BWA-MEM is run in all-alignments mode (using the `-a` option, as you should do for Polypolish alignments), it does not include the read sequence on every line. The primary alignment for each read will contain the sequence, but secondary alignments will only contain a `*` to save space. If the alignments for each read are not grouped together, Polypolish will be unable to get the read sequence for secondary alignments and will quit with an error like this:
```
Error: no alignments for read NS500764:85:H3J5TBGXF:2:12111:13314:18114 contain sequence
```

If your SAM files have gotten out of order, you can use the samtools 'sort by read name' option (`-n`) to make them compatible with Polypolish:
```
samtools sort -n -O sam alignments.sam > alignments_sorted.sam
```

Assuming your SAM files meet the above requirement (all alignments for each read are grouped on adjacent lines), then the order of the SAM file does _not_ matter. E.g. if you reverse the order of lines in your SAM file with [`tac`](https://www.gnu.org/software/coreutils/manual/html_node/tac-invocation.html), Polypolish will still run and it will produce identical output.

<br>

### Can I use Bwa-mem2 to align reads?

Yes! [Bwa-mem2](https://github.com/bwa-mem2/bwa-mem2) is a faster implementation of BWA-MEM. It produces nearly identical alignments to BWA-MEM, so its alignments are definitely appropriate for use with Polypolish.

<br>

### Can I use Bowtie2 to align reads?

[Bowtie2](http://bowtie-bio.sourceforge.net/bowtie2/index.shtml) is another popular short-read aligner, and like BWA-MEM, it has an option (`-a`) to align each read to all possible locations. So yes, you can use it to generate alignments for Polypolish. However, I used BWA-MEM when developing and testing Polypolish, and I've only briefly tried using Bowtie2. So BWA-MEM is probably the safer choice.

Example alignment commands with Bowtie2 might look something like this:
```bash
bowtie2-build draft.fasta draft.fasta
bowtie2 -a -p 16 -x draft.fasta -U reads_1.fastq.gz > alignments_1.sam
bowtie2 -a -p 16 -x draft.fasta -U reads_2.fastq.gz > alignments_2.sam
```

Paired-end reads usually have suffixes on read names (`/1` and `/2`). BWA-MEM removes these when making the SAM file (so first-in-pair and second-in-pair reads have the same name) but Bowtie2 does not. As of v0.7.0, [Polypolish's insert filter](#insert-size-filter) recognises `/1` and `/2` suffixes, so this will work.

<br>

### Can I use BBMap to align reads?

I don't have much experience with [BBMap](https://sourceforge.net/projects/bbmap), but with some help from [@baku4](https://github.com/baku4) (see [pull request #33](https://github.com/rrwick/Polypolish/pull/33)), I tried it out and it seems to work well. Run it like this:
```bash
bbmap.sh ref=draft.fasta in=reads_1.fastq.gz out=alignments_1.sam secondary=t sssr=0 maxsites=1000 ambiguous=all trd=t saa=f
bbmap.sh ref=draft.fasta in=reads_2.fastq.gz out=alignments_2.sam secondary=t sssr=0 maxsites=1000 ambiguous=all trd=t saa=f
polypolish filter --in1 alignments_1.sam --in2 alignments_2.sam --out1 filtered_1.sam --out2 filtered_2.sam
polypolish polish draft.fasta filtered_1.sam filtered_2.sam > polished.fasta
rm -r ref *.sam
```

<br>

### Should I run multiple rounds of Polypolish polishing?

You probably don't need to bother – Polypolish doesn't usually make changes after the first polishing round. But since Polypolish is unlikely to introduce an error into your assembly, you're welcome to try! Just don't be surprised if subsequent rounds of Polypolish don't do anything.

<br>

### Why does Polypolish only use end-to-end alignments?

You might have noticed that when loading alignments, Polypolish discards any which are not end-to-end. I.e. any alignments which are clipped on either end aren't included in the pileup. Here's an example from Polypolish output:
```
alignments_1.sam: 1,561,434 alignments from 1,405,200 reads
alignments_2.sam: 1,561,193 alignments from 1,405,200 reads

Filtering for high-quality end-to-end alignments:
  3,082,475 alignments kept
  40,152 alignments discarded
```

Assuming that your long-read assembly and your short reads came from the same genome (as they should), then I can think of three main reasons for clipped alignments. The first would be a significant structural error in the assembly, which Polypolish is not designed to fix (other polishing tools like [Pilon](https://github.com/broadinstitute/pilon) can do a better job with this kind of error). The second would be alignments at the start-end of a circular contig.

The third cause of clipped alignments would be from reads which are partially in a repeat. For example, if a read was half in a two-copy repeat (the boundary of the repeat was in the middle of the read), then we might expect two alignments: one where the read fully aligned end-to-end in its true location and one where half the read was clipped in the alignment, like this:
```
alignments:           TCTTTATTATTA                      ------TTATTA
assembly:   AGAGATTCGATCTTTATTATTATGCGGAATTCTGGTTGCCTCAAGGAAGCTTATTATGCGGAATAGAACCGTCCG
                            |   repeat   |                    |   repeat   |
```
In cases like this, clipped alignments represent incorrectly placed reads, so Polypolish discards them. This helps to reduce extraneous bases in the pileup and should improve Polypolish's ability to fix errors near the ends of repeats.

<br>

### Can Polypolish add/remove bases at the start/end of a sequence?

No, it cannot. Polypolish will only fix errors that are in the middle of your sequence, not errors right at the ends. For example, if your sequence was missing a few bases at its end, Polypolish will not add them back in. For a specific example, take a look at [this issue](https://github.com/rrwick/Polypolish/issues/1) where [Devon O'Rourke](https://github.com/devonorourke) set one up.

Adding/removing bases at the start/end of a contig gets tricky for circular sequences, and most bacterial sequences are circular. So I would recommend that you fix up the ends of your contigs before polishing with Polypolish, e.g. use [Autocycler](https://github.com/rrwick/Autocycler) which gives clean circularisation for bacterial genomes.

<br>

### Does Polypolish change contig names?

As of v0.6.0, Polypolish will _not_ change the names of contigs. It will, however, add `polypolish` to the contig's description.

For example, given this sequence as input:
```
>chromosome circular=true
ATGAATATAAAAGATTTTTTACTTGAGTTTAAAACTGAAA...
```

It will produce this output sequence:
```
>chromosome circular=true polypolish
ATGAATATAAAAGATTTTTTACTTGAGTTTAAAACTGAAA...
```

If you don't want `polypolish` added to the sequence descriptions, you can pipe Polypolish through sed:
```
polypolish polish draft.fasta filtered_1.sam filtered_2.sam | sed 's/ polypolish//' > polished.fasta
```

For how Polypolish used to behave prior to v0.6.0, see [issue #7](https://github.com/rrwick/Polypolish/issues/7).

<br>

### Why are `polypolish filter` and `polypolish polish` separate?

In [How to run Polypolish](#how-to-run-polypolish), you can see that two Polypolish commands are needed: `polypolish filter` and `polypolish polish`. You might wonder why I didn't combine these together so Polypolish is simpler to run?

This is because the `polypolish filter` command only applies to paired-end read sets, so it isn't needed for unpaired reads. Also, if you have multiple different paired-end read sets (e.g. you sequenced your isolate multiple times), then you must run `polypolish filter` separately for each of the paired-end sets before giving all filtered alignments to `polypolish polish`.

<br>

### Saving Polypolish's log to file

Polypolish outputs human-readable information to `stderr` but doesn't create a log file. If you'd like to save the log output to a file while still seeing it in the terminal, you can use the `tee` command as follows:
```bash
polypolish filter --in1 alignments_1.sam --in2 alignments_2.sam --out1 filtered_1.sam --out2 filtered_2.sam 2> >(tee polypolish.log)
polypolish polish draft.fasta filtered_1.sam filtered_2.sam 1> polished.fasta 2> >(tee -a polypolish.log)
```

The first command creates a new log file named `polypolish.log`, and the second command appends to this file.

By default, this log file will include [ANSI escape codes](https://en.wikipedia.org/wiki/ANSI_escape_code) for terminal formatting (e.g., colors and bold text). If you'd prefer a 'clean' log without formatting, use the following commands to strip out the escape codes:
```bash
polypolish filter --in1 alignments_1.sam --in2 alignments_2.sam --out1 filtered_1.sam --out2 filtered_2.sam 2> >(tee >(sed 's/\x1b\[[0-9;]*m//g' > polypolish.log))
polypolish polish draft.fasta filtered_1.sam filtered_2.sam 1> polished.fasta 2> >(tee >(sed 's/\x1b\[[0-9;]*m//g' >> polypolish.log))
```
