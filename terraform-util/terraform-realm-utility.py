#!/usr/bin/env python3
"""
Reads YAML configurations for realm deployments and generates directories,
terraform scripts from Mako templates, and bootstraps/plans/applies/destroys
the environment in the correct order of operations.
"""
import argparse
import json
import pathlib
import os
import shutil
import subprocess
import sys
from distutils.dir_util import copy_tree

import yaml
from mako.template import Template


def merge_defaults(defaults, realm):
  """Merges defaults config and realm config in a way that ensures
  that proper structure is preserved.  The default and realm
  configs do not exactly map to each other, so this will merge
  specific default configs into the proper realm config locations
  based on the given context for each."""

  # Globals are merged into merged_configs root.
  merged_configs = {**defaults["globals"], **realm["globals"]}
  # If terraform_providers is empty in realm, use defaults.
  if "terraform_providers" in realm["globals"] and not realm["globals"]["terraform_providers"]:
      merged_configs["terraform_providers"] = defaults["globals"]["terraform_providers"]  

  # Only merge action_order from realm if fully populated.
  merged_configs["action_order"] = defaults["action_order"]
  for action, order in defaults["action_order"].items():
    if "action_order" in realm:
      if action in realm["action_order"] and realm["action_order"][action]:
        merged_configs["action_order"][action] = realm["action_order"][action]

  # Merge environment configs
  merged_configs["environments"] = {}
  for env, env_configs in realm["environments"].items():
    merged_configs["environments"][env] = {
      **defaults["environment_defaults"], **env_configs
    }
    # Merge k8_clusters configs
    if "k8_clusters" in env_configs and env_configs["k8_clusters"]:
      for cluster, k8_configs in env_configs["k8_clusters"].items():
        merged_configs["environments"][env]["k8_clusters"][cluster] = {
          **defaults["k8_defaults"], **k8_configs
        }
        # Merge node_groups configs
        if "node_groups" in k8_configs and k8_configs["node_groups"]:
          for node_group, node_configs in k8_configs["node_groups"].items():
            merged_configs["environments"][env]["k8_clusters"][cluster]["node_groups"][node_group] = {
              **defaults["node_group_defaults"], **node_configs
            }

  return merged_configs


def template_work_order(configs, templates_dir, dest_dir):
  """Returns a dict of folders, files, and templates to be created

  returns work_order = {
    "full_dest_path": {
      "source": "full_source_path",
      "templates": [
        "files_ending_in_.mako"
      ],
      "copy_files": [
        "files_not_ending_in_.mako"
      ],
      "configs" : {merged_template_variables_map}
    }
  }
  """

  work_order = {}
  for root, directories, files in os.walk(templates_dir):
    # Trim templates_dir from path
    root_no_templates = root.replace(templates_dir, "")
    if files:
      dest = os.path.abspath(
        os.path.join(
          dest_dir,
          root_no_templates
        )
      )
      templates = [
        file for file in files
        if os.path.isfile(os.path.join(root, file))
        and ".mako" in file
      ]
      copy_files = [
        file for file in files
        if os.path.isfile(os.path.join(root, file))
        and ".mako" not in file
      ]
      work_order[dest] = {}
      work_order[dest]["source"] = os.path.abspath(root)
      work_order[dest]["templates"] = templates
      work_order[dest]["copy_files"] = copy_files
      work_order[dest]["configs"] = configs

  return work_order


def gen_global_workorder(realm_configs, templates_dir, root_dest):
  """Returns the work order for the global templates"""

  # "environments" and "action_order" are not needed for global_configs
  global_configs = {**realm_configs}
  del global_configs["environments"]
  del global_configs["action_order"]

  realm = global_configs["realm"]
  
  dest_prefix = f"{root_dest}/{realm}/global"
  work_order = template_work_order(
    global_configs,
    templates_dir,
    dest_prefix
  )

  return work_order


def gen_env_workorder(realm_configs, templates_dir, root_dest):
  """Returns the work order for environment templates"""
  environments_work_order = {}

  for env, config in realm_configs["environments"].items():
    # Merge all environment configs to root.
    env_configs = {**realm_configs, **config}

    # "environments" and "action_order" are not needed for env_configs.
    del env_configs["environments"]
    del env_configs["action_order"]

    env_configs["environment"] = env
    realm = env_configs["realm"]
    dest_prefix = f"{root_dest}/{realm}/{env}"
    env_work_order = template_work_order(
      env_configs,
      templates_dir,
      dest_prefix
    )
    environments_work_order.update(env_work_order)

  return environments_work_order


def gen_templates(complete_work_order, mako_modules):
  """Generates backend terraform configs from final work order"""

  for dest_folder, order in complete_work_order["templates"].items():
    p = pathlib.Path(dest_folder)
    p.mkdir(parents=True, exist_ok=True)

    for mako_file in order["templates"]:
      if mako_modules:
        template = Template(
          filename=f"{order['source']}/{mako_file}",
          module_directory=mako_modules
        )
      else:
        template = Template(filename=f"{order['source']}/{mako_file}") 
      filename = mako_file.replace(".mako", "")
      path = f"{dest_folder}/{filename}"

      with open(path, "w") as f:
        rendered = template.render(**order["configs"])
        f.write(rendered)
      # Make sure executable templates are executable
      if ".sh" in path:
        os.chmod(path, 0o744)

    for copy_file in order["copy_files"]:
      source_file = f"{order['source']}/{copy_file}"
      dest_file = f"{dest_folder}/{copy_file}"
      shutil.copy(source_file, dest_file)

  return None


def compile_work_order(configs, templates_dir, destination):
  """Complies a dictionary action plan"""

  complete_work_order = {}

  global_work_order = gen_global_workorder(
    configs,
    f"{templates_dir}/global/",
    destination
  )

  environments_work_order = gen_env_workorder(
    configs,
    f"{templates_dir}/deployment",
    destination
  )
  complete_work_order["templates"] = {**global_work_order, **environments_work_order}

  return complete_work_order


def gen_action_plan(action, dest, realm_configs, work_order):
  """Returns ordered action plan list."""

  def actions(action, folder_path, work_order):
    """Returns a list of actions to take. If override {action}.sh script
    exists in folder_path, returns [action_script].
    Otherwise, returns the default_actions."""
    action_script = os.path.join(folder_path, f"{action}.sh")
    # In case action is being run before any templates have been generated.
    if "templates" in work_order:
      script_in_work_order = any([
          f"{action}.sh.mako" in work_order["templates"][folder_path]["templates"],
          f"{action}.sh" in work_order["templates"][folder_path]["copy_files"]
        ])
    else:
      script_in_work_order = False
    if os.path.isfile(action_script) or script_in_work_order:
      return [action_script]
    else:
      return work_order["default_actions"][action]

  action_plan = {}

  if action == "destroy":
    order = realm_configs["action_order"]["destroy"]
  else:
    order = realm_configs["action_order"]["apply"]

  for folder in order:
    # Expands and converts the substring "environments" in the
    # action_order config to each environment defined in the
    # realm config.
    if "environments" in folder:
      for env in realm_configs["environments"]:
        folder_path = os.path.abspath(
          os.path.join(
            dest,
            realm_configs["realm"],
            folder)
        ).replace("environments", env)
        action_plan[folder_path] = actions(
          action,
          folder_path,
          work_order
        )
    else:
      folder_path = os.path.abspath(
        os.path.join(
          dest,
          realm_configs["realm"],
          folder)
      )
      action_plan[folder_path] = actions(
        action,
        folder_path,
        work_order
      )

  return action_plan


def exec_action(action, work_order):
  """Sequentially executes action scripts in work_order."""

  if "AWS_PROFILE" not in os.environ:
    print("AWS_PROFILE not set. Exiting...")
    sys.exit(1)
  else:
    print(f"\n=====\nAWS_PROFILE={os.environ['AWS_PROFILE']}\n=====\n")

  # Confirm actions other than plan
  if action != "plan" and sys.stdout.isatty():
    action_list = [
      folder for folder in work_order["action_plan"].keys()
    ]
    confirm = input(
      f"\n{action.capitalize()} {json.dumps(action_list, indent=2)}"
      f"\nAre you sure? (y/n): "
    )
    if confirm[0].lower() != "y":
      print(f"Cancelling {action} action.")
      sys.exit()

  print(f"Executing \"{action}\" action plan...")
  for folder, actions in work_order["action_plan"].items():
    if os.path.isdir(folder):
      for cmd in actions:
        print(f"Executing `{cmd}` in {folder}")
        subprocess.run(cmd.split(), cwd=folder, check=True)
    else:
      print(f"{folder} does not exist. Skipping {action}...")

    # Clean up destroyed folders.
    if action == "destroy":
      if os.path.isdir(folder):
        shutil.rmtree(folder, ignore_errors=False, onerror=None)

  return None  


def main():
  """Do the thing"""
  parser = argparse.ArgumentParser(
    description="Generate and/or execute new terraform environments."
  )
  parser.add_argument(
    "realm_config",
    type=str,
    help="YAML config file for realm."
  )
  parser.add_argument(
    "destination",
    type=str,
    help="Location of the root destination terraform config directory."
  )
  parser.add_argument(
    "--modules_source",
    type=str,
    default="../modules/",
    help="The source modules folder. Default='../modules/'"
  )
  parser.add_argument(
    "--modules_dest",
    type=str,
    help="Copy source modules to this target directory."
  )
  parser.add_argument(
    "--templates",
    type=str,
    default="templates",
    help="Location of the templates directory. Default=templates"
  )
  parser.add_argument(
    "--action",
    default=None,
    choices=[
      "bootstrap",
      "plan",
      "apply",
      "destroy"],
    help="Optional terraform action to take for realm."
  )
  parser.add_argument(
    "--skip_templates",
    default=False,
    action="store_true",
    help="Skip template generation."
  )
  parser.add_argument(
    "--target_env",
    type=str,
    help="Only act on target environment in realm."
  )
  parser.add_argument(
    "--mako_modules",
    type=str,
    default="",
    help="Troubleshooting: generate Mako template modules in this directory."
  )
  parser.add_argument(
    "--dry_run",
    default=False,
    action="store_true",
    help="Troubleshooting: displays work_order. "
    "Skips template generation and action scripts."
  )
  args = parser.parse_args()

  work_order = {}

  print("Terraform Environment Utility started. Loading defaults.yaml ...")
  with open("defaults.yaml", "r") as f:
    default_configs = yaml.safe_load(f.read())

  print(f"Loading {args.realm_config} ...")
  with open(args.realm_config, "r") as f:
    realm_configs = yaml.safe_load(f.read())

  print(f"Merging {args.realm_config} with defaults...")
  realm_configs = merge_defaults(default_configs, realm_configs)

  if args.target_env:
    if args.target_env in realm_configs["environments"]:
      realm_configs["environments"] = {
        args.target_env: realm_configs["environments"][args.target_env]
      }
      # Even if targeting a specific environment, the environments are dependent on
      # higher global resources, so they must be applied first regardless. Do not override
      # "apply" list.
      # However, when destroying, only target the environment deployment configs
      # to prevent global resources other environments depend on from being destroyed.
      if args.action == "destroy":
        realm_configs["action_order"] = {
          "destroy": [
            config for config in realm_configs["action_order"]["destroy"]
            if "environments" in config
          ]
        }
      print(f"Targeting environment {args.target_env}...")
    else:
      print(f"{args.target_env} environment not found in {args.realm_config}. Closing...")
      sys.exit(1)

  print("Config loaded. Compiling work order...")
  if not args.skip_templates:
    work_order = compile_work_order(
        realm_configs,
        args.templates,
        args.destination
      )
  
  # Copy default_actions. Do not attempt to override these
  # in the realm_config, instead place an {action}.sh script
  # in the config folder to override defaults.
  work_order["default_actions"] = default_configs["default_actions"]

  if args.action:
    print(f"Adding {args.action} action plan to work order")
    work_order["action_plan"] = gen_action_plan(
      args.action,
      args.destination,
      realm_configs,
      work_order
      )

  # Troubleshooting: if set, display work_order and exit.
  if args.dry_run:
    print(f"Displaying work_order:\n{json.dumps(work_order, indent=2)}")
    sys.exit()

  if args.modules_dest:
    print(f"Copying modules into {args.modules_dest}...")
    copy_tree(args.modules_source, args.modules_dest, dirs_exist_ok=True)

  if args.skip_templates:
    print("Work order compiled.  Skipping template generation.")
  else:
    print("Work order compiled. Generating realm templates...")
    gen_templates(work_order, args.mako_modules)
    print("Formatting Terraform...")
    for folder in work_order["templates"]:
      subprocess.run(["terraform", "fmt"], cwd=folder, check=True)
    print("Templates generated and formatted successfully.")

  if args.action:
    exec_action(args.action, work_order)
    print(f"\"{args.action}\" action plan completed successfully.")


if __name__ == '__main__':
  main()
