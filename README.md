# action-opcache-reset

---

## Tag Conventions for Releases

We follow specific tag conventions for pull requests merged into the `main` branch to maintain versioning and compatibility. Please adhere to the following guidelines:

### Creating New/Updated Tags

When ready to release a new version, please follow these steps to create a new tag:

1. Identify what the new full semantic version and major versions should be, based on the sections below
2. Run the command `git tag <full_semantic_version> && git push origin :refs/tags/<major_version> && git tag -f <major_version> && git push origin --tags`
    1. When you delete the major version tag, it will briefly break any deployments
    2. To minimize the impact of this, we chain these together so they run as quickly as possible
3. In Github, view repo tags and confirm that your new tag is appearing

### Full Semantic Versioning Tags (Immutable)

All pull requests merged into `main` should be tagged with full semantic versioning. Examples:

-   v1.0.0
-   v1.0.1

These tags that are fully versioned should be immutable - we should never delete these tags or point them to a different commit.

### Major Versioning Tags (Mutable)

For major releases, create a new tag with only the major version number. Example:

-   v1

These tags are mutable, and we will update them to point to different commits as needed. This is in addition to the full semantic versioned tag.

### Usage in Other Repositories

Unless testing or conducting a beta test/rollout, use major releases when referencing the shared-workflows repo from other repositories. Example:

`WebpageFX/action-opcache-reset@v1`

## Adding to an Existing Repo

If you need to clear opcache on a site as part of your workflow, add this within the `jobs` section of your shared workflow (updating the version as appropriate and adding any vars that aren't defined in the environment):

```yaml
opcache:
    runs-on: ubuntu-latest
    needs: deploy
    environment: ${{ github.ref_name }}
    steps:
        - name: Clear Opcache
          uses: WebpageFX/action-opcache-reset@v1
          with:
              domain: ${{ vars.TARGET_DOMAIN }}
              webroot: '${{ vars.TARGET_REPO }}/deploy/${{ github.ref_name }}/current/www/'
              php_executable: ${{ vars.PHP_PATH }}
              owner: ${{ vars.FILE_OWNER || vars.TARGET_USER }}
              group: ${{ vars.FILE_GROUP || vars.TARGET_USER }}
              permissions: ${{ vars.FILE_PERMISSIONS || 644 }}
              ssh_user: ${{ vars.TARGET_USER }}
              ssh_host: ${{ vars.TARGET_HOST }}
              ssh_port: ${{ vars.TARGET_PORT || 22 }}
              ssh_key: ${{ secrets.REPO_PRIVATE_KEY }}
```

## Inputs

There are many inputs available to customize the behavior of this action. Some are required and some are optional. The following table describes each input and its purpose.

| Input                               | Required | Default | Description                                                         |
| ----------------------------------- | -------- | ------- | ------------------------------------------------------------------- |
| `domain`                            | Yes      | N/A     | The domain name of the site to clear opcache for.                   |
| `webroot`                           | Yes      | N/A     | The full path to the webroot of the site to clear opcache for.      |
| `php_executable`                    | No       | `php`   | The full path to the PHP executable to use.                         |
| `owner`                             | No       | N/A     | The owner of the site files to make it accessible via the web       |
| `group`                             | No       | N/A     | The group of the site files to make it accessible via the web       |
| `permissions`                       | No       | `644`   | The permissions of the site files to make it accessible via the web |
| `ssh_user`                          | Yes      | N/A     | The SSH user to connect to the server as.                           |
| `ssh_host`                          | Yes      | N/A     | The SSH host to connect to.                                         |
| `ssh_port`                          | No       | `22`    | The SSH port to connect to.                                         |
| `ssh_key`                           | Yes      | N/A     | The SSH private key to use to connect to the server.                |
| `max_attempts_opcache_reset_http`   | No       | `3`     | The number of times to try the opcache reset HTTP request. Set to 0 to disable request.          |
| `max_attempts_opcache_reset_cli`    | No       | `1`     | The number of times to try the opcache reset CLI request. Set to 0 to disablecommand.           |
| `delay_attempts_opcache_reset_http` | No       | `5`     | The number of seconds to wait between opcache reset HTTP attempts.  |
| `delay_attempts_opcache_reset_cli`  | No       | `5`     | The number of seconds to wait between opcache reset CLI attempts.   |
