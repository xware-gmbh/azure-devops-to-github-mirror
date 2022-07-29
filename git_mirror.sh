#! /bin/bash

mirror_list_file="mirrors-private.csv"

pat2b64() {
    pat_b64=$(echo -n ":$1" | base64)
    echo $pat_b64
}

# get PATs from cli
src_pat=$1
dst_pat=$2
src_pat_b64=$(pat2b64 $src_pat)
dst_pat_b64=$(pat2b64 $dst_pat)

# check for mirror list
echo -e "Check Mirror List"
if [ ! -f "$mirror_list_file" ]; then
    echo "$mirror_list_file does not exist!"
    exit
fi

# mirror each pair in the mirror list
current_line=0
{
read
while IFS=";" read -r src_repo src_branch dst_repo dst_branch email name
do

    let current_line++
    echo "Start with line ""$current_line"""
    tmp_repo_name="mirror_""$current_line"""

    if [[ -z "$src_repo" || -z "$dst_repo" ]]; then

        echo -e "Faulty list entry in $mirror_list_file line $current_line!"
        continue

    else

        echo -e "Mirroring from: $src_repo\nTo: $dst_repo\nWith user: $name ($email)"
        
        # clone source
        git -c http.extraHeader="Authorization: Basic $src_pat_b64" clone $src_repo $tmp_repo_name

        if [[ ! "$?" == "0" ]]; then

            echo -e "Failed to clone the source repo for mirror $current_line!"
            continue

        else

            cd $tmp_repo_name

            # make git not cry            
            git config user.email "$email"
            git config user.name "$name"

            # remove all the AZDO system refs
            git for-each-ref --format='%(refname)' refs/pull | xargs -I{} git update-ref -d {}

            # remove files that are private
            find . -mindepth 1 -maxdepth 1 -type d -name '*private*' -exec rm -rf {} \;
            find . -type f -name '*private*' -exec rm -f {} \;

            # remove history
            # https://stackoverflow.com/questions/13716658/how-to-delete-all-commit-history-in-github
            git checkout --orphan latest_branch
            git add -A
            git commit -am "Sync to Github"
            git branch -D $src_branch
            git branch -m $dst_branch

            # trick talisman when locally testing
            rm -f .git/hooks/pre-push
            cd ..

            # push source to destination
            git -C $tmp_repo_name \
                push --verbose --force \
                https://token:$dst_pat@github.com/$dst_repo

        fi

        # cleanup
        rm -rf $tmp_repo_name

    fi
done
} < "$mirror_list_file"