#! /bin/bash

mirror_list_file="mirrors-private.csv"

pat2b64() {
    pat_b64=$(echo -n ":$1" | base64)
    echo "$pat_b64"
}

# get PATs from cli
src_pat=$1
dst_pat=$2
src_pat_b64=$(pat2b64 "$src_pat")
# dst_pat_b64=$(pat2b64 "$dst_pat") # only needed if you mirror from Azure DevOps to Azure DevOps

# check for mirror list
echo -e "Check Mirror List"
if [ ! -f "$mirror_list_file" ]; then
    echo "$mirror_list_file does not exist!"
    exit
fi

# mirror each pair in the mirror list
current_line=0
{
read -r
while IFS=";" read -r src_repo src_branch dst_repo dst_branch email name
do

    (( current_line++ )) || true
    echo "Start with line ""$current_line"""
    tmp_repo_name="mirror_""$current_line"""

    if [[ -z "$src_repo" || -z "$dst_repo" ]]; then

        echo -e "Faulty list entry in $mirror_list_file line $current_line!"
        continue

    else

        echo -e "Mirroring from: $src_repo\nTo: $dst_repo\nWith user: $name ($email)"
        
        # Clone source
        if git -c http.extraHeader="Authorization: Basic $src_pat_b64" clone "$src_repo" $tmp_repo_name --depth 1 2>&1
        then

            cd $tmp_repo_name || echo "Folder $tmp_repo_name not found."

            # We need a user to commit to the mirror destination and we cannot simply read one from the last commit as this can be random
            # Sometimes it might also make sense to make use of a service user here to make it 100% sure that these commits are not done by a human
            git config user.email "$email"
            git config user.name "$name"

            # Remove all the AZDO system refs
            # We keep refs/tags as they might be needed
            git for-each-ref --format='%(refname)' refs/pull | xargs -I{} git update-ref -d {} 2>&1
            git for-each-ref --format='%(refname)' refs/heads | xargs -I{} git update-ref -d {} 2>&1
            git for-each-ref --format='%(refname)' refs/remotes | xargs -I{} git update-ref -d {} 2>&1
            # Prune all unreachable objects aftzer refs have been removed
            git prune 2>&1

            # Remove folders and files that have "private" in their name e.g. specific local configs you don't want to mirror
            find . -mindepth 1 -maxdepth 1 -type d -name '*private*' -exec rm -rf {} \;
            find . -type d -name '*private*' -exec rm -rf {} \;
            find . -type f -name '*private*' -exec rm -f {} \;

            # Remove history
            # Source: https://stackoverflow.com/questions/13716658/how-to-delete-all-commit-history-in-github
            # We have to go with this option as "git clone --depth 1" alone is not sufficient and leads to the error "shallow update not allowed"
            # For details see: https://stackoverflow.com/questions/28983842/remote-rejected-shallow-update-not-allowed-after-changing-git-remote-url
            git checkout --orphan "$src_branch" 2>&1
            git add -A
            git commit -am "Sync to Github" 2>&1
            git branch -m "$dst_branch" 2>&1

            # trick talisman when locally testing
            rm -f .git/hooks/pre-push

            # push source to destination
            if git push --force \
                https://token:"$dst_pat"@github.com/"$dst_repo" 2>&1
            then
                echo "Successfully pushed the changes."
            else
                >&2 echo "Error: Failed to push the changes. Please check if the PAT has expired."
                exit 1
            fi
            
            # cleanup
            cd ..
            rm -rf $tmp_repo_name

        else

            >&2 echo -e "Error: Failed to clone the source repo for mirror $current_line! Please check if the PAT has expired."
            exit 1

        fi
    fi
done
} < "$mirror_list_file"
