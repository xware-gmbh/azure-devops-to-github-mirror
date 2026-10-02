# GitMirror - sharing is caring

![Two persons with books sharing knowledge](.images/two-persons-with-books-sharing-knowledge.jpg "Two persons with books sharing knowledge")
Sharing is caring: improve yourself and help the people around you by sharing knowledge. (Photo by [cottonbro from Pexels](https://www.pexels.com/photo/boy-in-white-dress-shirt-sitting-on-couch-4861357/))

Mirror private Azure DevOps repositories to public Github repos to share know-how, proof of concepts, or other valuable content which would otherwise gather dust in your company. The git-history and private files can be deleted in the process to prevent sharing confidential information by accident.

## Usage

The `mirrors.csv` file contains a semicolon-separated set of information for the mirroring process. Each line represents one mirroring pair. The values are:

- `SourceRepo` = Azure DevOps source repository; the format is usually: `https://organization.visualstudio.com/collection/project/_git/repo`
- `SourceBranch` = Default branch of the source repository, most likely main, master, trunk, or such
- `DestinationRepo` = Github destination branch without the github.com part; format is usually: organization/repo.git
- `DestinationBranch` = Default branch of the destination repository, most likely main, master, trunk, or such
- `Email` = email address of the Github user which will be set for the commit
- `Name` = Name address of the Github user which will be set for the commit

An example line looks like follows and can also be found in the example file `mirrors-example.csv`.

```csv
SourceRepo;SourceBranch;DestinationRepo;DestinationBranch;Email;Name;
https://organization.visualstudio.com/collection/project/_git/repo;main;organization/repo.git;trunc;jan@jambor.pro;Jan Jambor;
```

All folders or files which contain a `private` in their name will be deleted in the process. So you can ensure that confidential information is not shared while examples are. For example in the private version of this repo I have two files:

- `mirrors-example.csv` is also here in the public version of the repo
- `mirrors-private.csv` is removed in the sync process

You need a Personal Access Token (PAT) from both, source and destination repositories. Ensure that each PAT can only do what it must do. `pat-source` should have only reading permission. `pat-destination` needs write permissions.

If you run the script manually you can now run this:

```bash
bash git_mirror.sh <src PAT> <dst PAT>
bash git_mirror.sh $PAT_SOURCE $PAT_DESTINATION
```

If you are using Azure Pipelines to trigger the sync, you must have a library with the variables `pat-source` and `pat-destination`. You can check the example pipeline [azure-pipelines.yml](azure-pipelines.yml) which makes use of a library called `GitMirror`.
