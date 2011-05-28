Paparazzi
=========

Paparazzi is a Ruby gem for making incremental snapshot rsync backups of a directory, maintaining
hourly, daily, weekly, monthy, and yearly snapshots of directory state and files without consuming
much more drive space than a single copy would (depending on how frequently existing files change).

Only changed or new files are copied to the new snapshot. Hard links are created in the new snapshot
to previously existing unchanged files, allowing for frequent backups to be made of very large
directories (see 'How it works' below). Older snapshots maintain versions of files as they existed
at the time that snapshot was made.

Paparazzi automatically purges out old snapshots, and allows you to define how many of each snapshot
to keep in reserve.

Installation
------------

    gem install paparazzi
    

Usage
-----

Create a ruby script that you'll run hourly from a cron.
 
    require 'rubygems' #unless you use another gem package manager
    require 'paparazzi'
    
    settings = {
      :source => '/full/path/to/source/directory/',           # note the trailing '/'
      :destination => '/mnt/external_drive/backup_folder',
      :rsync_flags => '-L --exclude lost+found'
    }                                                         

    Paparazzi::Camera.trigger(settings)
    
    
Available Settings
------------------

  * `:source`      **required** The source folder to be backed up. Trailing '/' recommended. See rsync manpage
                     for explanation of trailing '/' 
  * `:destination` **required** The destination folder for backups to be written to, preferably on a different
                     physical drive.
  * `:intervals`    A hash of snapshot intervals and number of snapshots of each to keep before purging.
                     default: `{:hourly => 24, :daily => 7, :weekly => 5, :monthly => 12, :yearly => 9999}` 
  * `:rsync_flags` Additional flags to pass to rsync. Paparazzi uses `-aq`, `--delete`, & `--link_dest`, plus
                     whatever you add. The author suggests considering `-L` and `--exclude`.


Supported Operating Systems
---------------------------

Paparazzi is developed and tested on Ubuntu Linux and should work fine on all other flavors. As of version 0.1.1, all
tests reportedly passed on Max OSX, and it is expected that Paparazzi will probably run very well in that environment
(although it is not actively tested, so run at your own risk).

It is highly unlikely that Paparazzi will run on an MS Windows based machine without a whole lot of TLC by the user,
if it runs at all. At a minimum, the user will need to get rsync installed on the machine, possibly through cygwin,
but this is not supported at all by the author and users are entirely on their own.


How it works.
-------------

Paparazzi uses rsync's ability to make hard links to files that haven't changed from previous
backups. So, even though multiple incremental versions of the entire directory are kept, only a single
copy of unique files are kept, with multiple hard links in separate snapshots pointing to the same
file.

This gem owes it's existance to Mike Rubel's excellent write-up
[Easy Automated Snapshot-Style Backups with Linux and Rsync](http://www.mikerubel.org/computers/rsync_snapshots/).
If you're not sure what "hard links" are or are confused how multiple snapshot versions of a
directory can be made without taking up much more space than a single copy, then read his post.
