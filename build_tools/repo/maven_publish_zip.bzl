_TEMPLATE = """
mvn deploy:deploy-file -DgroupId={group_id} -DartifactId={artifact_id} -Dversion={version} -Dpackaging=zip -Dfile={zip_file} -Durl={url} -Dclassifier={classifier} -DgeneratePom={generate_pom}
"""

def _maven_publish_impl(ctx):
    if ctx.attr.is_windows:
        executable = ctx.actions.declare_file("%s-publisher.bat" % ctx.attr.name)
    else:
        executable = ctx.actions.declare_file("%s-publisher" % ctx.attr.name)

    coordinates_substituted = ctx.attr.coordinates.format(publishing_version = ctx.var["publishing_version"])

    # Not currently used but may use in the future
    maven_repo = ctx.var.get("maven_repo", "''")
    user = ctx.var.get("maven_user", "''")
    password = ctx.var.get("maven_password", "''")
    generate_pom = ctx.var.get("publishing_nativezip_generate_pom", "false")

    coordinates_split = coordinates_substituted.split(":")
    group_id = coordinates_split[0]
    artifact_id = coordinates_split[1]
    version = coordinates_split[2]

    ctx.actions.write(
        output = executable,
        is_executable = True,
        content = _TEMPLATE.format(
            group_id = group_id,
            artifact_id = artifact_id,
            version = version,
            zip_file = ctx.file.zip_file.short_path,
            url = maven_repo,
            classifier = ctx.attr.classifier,
            generate_pom = generate_pom
        ),
    )

    files = [
        ctx.file.zip_file,
    ]

    return [
        DefaultInfo(
            files = depset([executable]),
            executable = executable,
            runfiles = ctx.runfiles(
                files = files,
                collect_data = True,
            ).merge(ctx.attr._uploader[DefaultInfo].data_runfiles),
        ),
    ]

maven_publish_zip_def = rule(
    _maven_publish_impl,
    doc = """Publish artifacts to a maven repository.
The maven repository may accessed locally using a `file://` URL, or
remotely using an `https://` URL. The following flags may be set
using `--define`:
  gpg_sign: Whether to sign artifacts using GPG
  maven_repo: A URL for the repo to use. May be "https" or "file".
  maven_user: The user name to use when uploading to the maven repository.
  maven_password: The password to use when uploading to the maven repository.
When signing with GPG, the current default key is used.
""",
    executable = True,
    attrs = {
        "coordinates": attr.string(
            mandatory = True,
        ),
        "zip_file": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "_uploader": attr.label(
            executable = True,
            cfg = "host",
            default = "//build_tools/repo:maven-zip-publisher",
            allow_files = True,
        ),
        "is_windows": attr.bool(mandatory = True),
        "classifier": attr.string(mandatory = True),
    },
)

def maven_publish_zip(name, **kwargs):
    maven_publish_zip_def(
        name = name,
        is_windows = select({
            "//build_tools/platforms:is_windows": True,
            "//conditions:default": False,
        }),
        **kwargs
    )
