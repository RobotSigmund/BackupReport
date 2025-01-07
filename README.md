# BackupReport

Generate a report showing common pitfalls and highlights bad practices.


# Example report

[RepoScore.md](https://github.com/RobotSigmund/BackupReport/blob/d60a30e0c6a41e87f91fb9ed6fbccbc332c85455/RepoScore.md)


# Supported checks

* Routine length

Any routine exceeding 30 lines of code will generate a warning. Routine exceeding 50 lines of code will generate errors. Instructions will be counted, however loops, conditional expressions (if, for, while etc.) and comments will not be counted.

* Routine comments

Routines without 1/3 comment ratio will generate warnings.

* IO Prefixes

IOs should have di/do/gi/go/ai/ao prefix. Additionally system-IO should have sdi/sdo, etc. Incorrectly named IO will generate errors.

* IO Labels and categories

IOs should have clearly defined labels and categories. IOs with missing labels and category information will generate errors.

* IO Access level

According to ISO10218 IOs should which can generate dangerous movements within a robotcell should be prevented from being remotely operated. This means access level should be defined with remote access prevented. "-Access All" IOs will generate warnings.

* Programdata prefix

All programdata should be prefixed according to ABB documentation. Missing or wrong prefix will generate errors.

* Task shared programdata

Task shared programdata should be minimized to maintain simplicity. Each task is allowed 3 shared PERS variables, any more will generate warnings.

* Instructions to be avoided

Any GOTOs will generate errors. Anything solved with GOTO can be rewritten to be more readable. Use ChatGPT if you are unable to refactor yourself.

Late binding calls are sometimes good alternatives, however these will reduce readability and instances will be highlighted.

  
  





