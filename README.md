Paparazzi
=========

Paparazzi is a Ruby gem for making incremental snapshot rsync backups of a directory, maintaining
hourly, daily, weekly, monthy, and yearly snapshots of directory state and files without consuming
much more drive space than a single copy would (depending on how frequently existing files change).

Only changed or new files are copied to the new snapshot. Hard links are created in the new snapshot
to previously existing unchanged files, allowing for frequent backups to be made of very large
directories (see 'How it works' below). Older snapshots maintain versions of files as they existed
at the time that snapshot was made.

Paparazzi automatically purges out old hourly, daily, weekly, and monthly snapshots. Yearly
snapshots are not automatically purged and need to be removed manually when necessary.

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
      :rsync_flags => '-L  --exclude lost+found'              # see 'man rsync' for available options.
    }                                                         # Paparazzi sends '-aq --delete', plus whatever you add.

    Paparazzi::Camera.trigger(settings)
    

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
