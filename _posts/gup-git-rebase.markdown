---
layout: post
title: "<tt>gup</tt>: A friendlier <tt>git pull --rebase</tt>"
short: gup
date: 2010-11-09
updated: 2011-09-16
---

By now most `git` users would have heard about [rebasing your local commits](http://www.gitready.com/intermediate/2009/01/31/intro-to-rebase.html) on top of the remote branch HEAD before you `git push` them rather than merging to [prevent the proliferation of useless same branch merge commits](http://www.viget.com/extend/only-you-can-prevent-git-merge-commits/) like "Merge remote branch 'origin/topic' into topic".

If one is using `git pull`, the rebasing can be accomplished by using `git pull --rebase` instead. This essentially changes `git pull` from doing `git fetch && git merge $TRACKING_BRANCH` to `git fetch && git rebase $TRACKING_BRANCH`.

There's still the inconvenience of having to stash any uncommitted changes before a rebase. If you don't, you'll get messages like "refusing to pull with rebase: your working tree is not up-to-date". This results in a fetch, stash, rebase, pop dance which gets tiring. I think we can do better.

**Update 2011-01-11:** Another thing to watch out for when using `git pull --rebase` is merge commits. You cannot preserve merges when rebasing using `git pull` as it does not let you pass in the `--preserve-merges` option. This means you could end up losing valuable merge commits. Glen Maddern has a great post on [Rebasing Merge Commits in Git](http://notes.envato.com/developers/rebasing-merge-commits-in-git/) over on the [Envato Notes](http://notes.envato.com/) blog which covers this in more detail. The good news is that my `gup` script already handles rebasing merge commits by passing the `-p` (`--preserve-merges`) option to `git rebase`.

**Update 2011-09-16:** My `gup` function has had a number of tweaks since I first posted. I removed the quiet flag from `git stash pop` as late versions of `git` seem to silence the error when pop fails. The other significant change is that `gup` will now explicitly fast-forward if it can rather than rebasing. The rest of the changes are minor (e.g. refactoring for style).

**Update 2011-09-16:** I now prefer [`git-up`](https://github.com/aanand/git-up) when available as it has nicer output and it also has an option to show if one needs to `bundle`. I still use the `gup` function as it's handy on foreign systems where I don't my normal Ruby setup and I like the command name better :).

{% highlight bash %}
function gup
{
  # subshell for `set -e` and `trap`
  (
    set -e # fail immediately if there's a problem

    # use `git-up` if installed
    if type git-up > /dev/null 2>&1
    then
      exec git-up
    fi

    # fetch upstream changes
    git fetch

    BRANCH=$(git symbolic-ref -q HEAD)
    BRANCH=${BRANCH##refs/heads/}
    BRANCH=${BRANCH:-HEAD}

    if [ -z "$(git config branch.$BRANCH.remote)" -o -z "$(git config branch.$BRANCH.merge)" ]
    then
      echo "\"$BRANCH\" is not a tracking branch." >&2
      exit 1
    fi

    # create a temp file for capturing command output
    TEMPFILE="`mktemp -t gup.XXXXXX`"
    trap '{ rm -f "$TEMPFILE"; }' EXIT

    # if we're behind upstream, we need to update
    if git status | grep "# Your branch" > "$TEMPFILE"
    then

      # extract tracking branch from message
      UPSTREAM=$(cat "$TEMPFILE" | cut -d "'" -f 2)
      if [ -z "$UPSTREAM" ]
      then
        echo Could not detect upstream branch >&2
        exit 1
      fi

      # can we fast-forward?
      CAN_FF=1
      grep -q "can be fast-forwarded" "$TEMPFILE" || CAN_FF=0

      # stash any uncommitted changes
      git stash | tee "$TEMPFILE"
      [ "${PIPESTATUS[0]}" -eq 0 ] || exit 1

      # take note if anything was stashed
      HAVE_STASH=0
      grep -q "No local changes" "$TEMPFILE" || HAVE_STASH=1

      if [ "$CAN_FF" -ne 0 ]
      then
        # if nothing has changed locally, just fast foward.
        git merge --ff "$UPSTREAM"
      else
        # rebase our changes on top of upstream, but keep any merges
        git rebase -p "$UPSTREAM"
      fi

      # restore any stashed changes
      if [ "$HAVE_STASH" -ne 0 ]
      then
        git stash pop
      fi

    fi

  )
}
{% endhighlight %}

Throw the following into your shell's startup script. I keep the script in my [dotfiles](https://github.com/jasoncodes/dotfiles) as it's much easier to bring it along to new machines. Alternatively you could remove the function wrapper and save it as a standalone script in `~/bin`.

Once setup you can pull changes for the current tracking branch, rebase any unpushed commits on top of any new ones from upstream, all while preserving anything you have uncommitted (via `git stash`) with a single command: `gup`.
