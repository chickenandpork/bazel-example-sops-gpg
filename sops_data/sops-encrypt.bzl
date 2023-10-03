def sopfiles(ctx, f):
  """Return the sop file relative path of f."""
  return f.path

def declare_output(ctx, f, outputs):
  """Declare sop encrypted outputs"""
  out = ctx.actions.declare_file("enc." + f.basename)
  outputs.append(out)
  return out.path

# Load docker image providers
def _sops_encrypt_impl(ctx):
    """This impl. allows reference and encrypt secrets.yaml files using mozilla sops
    Args:
        name: A unique name for this rule.
        srcs: Array of eplaintext files to encrypt
        sops_yaml: Sops config file
    """
    inputs = [ctx.file.sops_yaml] + ctx.files.srcs
    outputs = []

    sops = ctx.toolchains["@com_github_masmovil_bazel_rules//toolchains/sops:toolchain_type"].sopsinfo.tool.files.to_list()[0]
    sops_yaml = ctx.file.sops_yaml.path

    gpg = ctx.toolchains["@com_github_masmovil_bazel_rules//toolchains/gpg:toolchain_type"].gpginfo.tool.files.to_list()[0]

    inputs += [gpg, sops]

    exec_file = ctx.actions.declare_file(ctx.label.name + "_helm_bash")

    # Generates the exec bash file with the provided substitutions
    ctx.actions.expand_template(
        template = ctx.file._script_template,
        output = exec_file,
        is_executable = True,
        substitutions = {
            "{ENCRYPT_FILES}": "\n".join([
              "\tencrypt_file %s %s" % (sopfiles(ctx, f), declare_output(ctx, f, outputs))
              for f in ctx.files.srcs]),
            "{SOPS_BINARY_PATH}": sops.path,
            "{SOPS_CONFIG_FILE}": sops_yaml,
            "{SOPS_PROVIDER}": ctx.attr.provider,
            "{GPG_BINARY}": gpg.path
        }
    )

    ctx.actions.run(
        inputs = inputs,
        outputs = outputs,
        arguments = [],
        executable = exec_file,
        execution_requirements = {
            "local": "1",
        },
        use_default_shell_env = True
    )

    return [
        DefaultInfo(
            files = depset(outputs)
        )
    ]

sops_encrypt = rule(
    implementation = _sops_encrypt_impl,
    attrs = {
      "srcs": attr.label_list(allow_files = True, mandatory = True),
      "sops_yaml": attr.label(allow_single_file = True, mandatory = True),
      "provider": attr.string(default = "gcp_kms"),
      "_script_template": attr.label(allow_single_file = True, default = ":sops-encrypt.sh.tpl"),
    },
    toolchains = [
        "@com_github_masmovil_bazel_rules//toolchains/sops:toolchain_type",
        "@com_github_masmovil_bazel_rules//toolchains/gpg:toolchain_type"
    ],
    doc = "Runs sops encrypt to encrypt secret files",
)
