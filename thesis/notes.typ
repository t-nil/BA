
#import "@preview/glossarium:0.5.10": gls, glspl, make-glossary, print-glossary, register-glossary
#show: make-glossary
#import "glossary.typ": glossary-list
#register-glossary(glossary-list)

= Sources

== INBOX
- https://www.cs.hmc.edu/%7Egeoff/classes/hmc.cs135.201001/homework/fuse/fuse_doc.html (from https://unix.stackexchange.com/questions/325473/in-fuse-how-do-i-get-th  e-information-about-the-user-and-the-process-that-is-try)
- https://security.googleblog.com/2022/12/memory-safe-languages-in-android-13.html (from @10592287)
- https://blog.reverberate.org/2025/02/03/no-panic-rust.html

== @10.1145_3102980.3103006
Difference:
- "safety concerns go beyond type systems"

= Notes

== Introduction
@10.1145_3102980.3103006 "Even worse, pervasive use of pointer aliasing, pointer arithmetic, and unsafe type casts keeps modern systems beyond the reach of software verification tools."



=== CVE data
@cvedetails.com_linuxkernel
@chen2011linux (ch-04, "unsafe language")

// TODO: what are good sources for "majority of system-level programs are written in C"?


==== methodology:
- for now, only linux kernel CVEs (then we can filter by CPE). this one paper also primarily cites a CVE analysis targeting linux kernel. EXTRA also consider other sources.
- maybe, for now, just focus on the CVE categories and maybe pick out some examples. looking at 3500 CVEs would be overkill anyways.
- @cvedetails.com_linuxkernel says that, in the last 10 years, 3439/3918 == 87.8% of linux kernel CVEs are memory-related (which we would atleast partially solve with Rust)
- EXTRA overflows would be interesting, but require more investigation into Rusts overflow behavior.

==== beispiel-CVEs
sources:
- https://nvd.nist.gov/vuln/search#/nvd/home?cnaSourceIdList=386&sortOrder=5&sortDirection=2&offset=125&rowCount=25&keyword=filesystem&cpeFilterMode=applicability&cpeName=cpe:2.3:o:linux:linux_kernel:*:*:*:*:*:*:*:*&resultType=records

maybe:
- https://nvd.nist.gov/vuln/detail/CVE-2024-46777 (overflow again)
- https://nvd.nist.gov/vuln/detail/CVE-2025-38415 (shift OOB)

// FIXME @löhr: schön auch hier auf die lücken im konzept eingehen. was kann mit meinem ansatz nicht gelöst werden (<-> auch future work / conclusion/limitations)

@procfs

*maybe*:
- https://nvd.nist.gov/vuln/detail/CVE-2025-21646
- https://nvd.nist.gov/vuln/detail/CVE-2026-23147

-
  - problem:
  - rust löst:  :green

== Implementation
The Rust Project Developers. 2017. Implementation of Rust stack unwinding.
https://doc.rust-lang.org/1.3.0/std/rt/unwind/.



#bibliography("bibliography.bib", style: "ieee")

#print-glossary(
  glossary-list,
)

// FIXME: @löhr
