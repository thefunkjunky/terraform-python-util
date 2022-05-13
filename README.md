# Terraform Realm Utility
This utility script is used to configure realms (AWS accounts) and realm deployments ("environments"), generate terraform templates from the configs, bootstrap new realms and environments, and plan, apply, or destroy realms/environments in the correct order of operations.

## Video Demo

In progress...

## Installation

1. `python3 -m venv venv`
1. `source venv/bin/activate`
1. `pip3 install -r requirements.txt`

Be sure to `source venv/bin/activate` before running the script

`deactivate` to exit the virtual environment.

## Basic usage
Basic overview of script usage and arguments.

**NOTE:** Be sure to first set the correct AWS_PROFILE for the account being targeted. Configure profiles in your ~/.aws directory per https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html#cli-configure-files-where and set the AWS_PROFILE environment variable (i.e. `export AWS_PROFILE=mycompany-dev`).
```
└─▶ ./terraform-realm-utility.py -h
usage: terraform-realm-utility.py [-h] [--modules_source MODULES_SOURCE]
                                  [--modules_dest MODULES_DEST]
                                  [--templates TEMPLATES]
                                  [--action {bootstrap,plan,apply,destroy}]
                                  [--skip_templates] [--target_env TARGET_ENV]
                                  [--mako_modules MAKO_MODULES] [--dry_run]
                                  realm_config destination

Generate and/or execute new terraform environments.

positional arguments:
  realm_config          YAML config file for realm.
  destination           Location of the root destination terraform config directory.

optional arguments:
  -h, --help            show this help message and exit
  --modules_source MODULES_SOURCE
                        The source modules folder. Default='../modules/'
  --modules_dest MODULES_DEST
                        Copy source modules to this target directory.
  --templates TEMPLATES
                        Location of the templates directory. Default=templates
  --action {bootstrap,plan,apply,destroy}
                        Optional terraform action to take for realm.
  --skip_templates      Skip template generation.
  --target_env TARGET_ENV
                        Only act on target environment in realm.
  --mako_modules MAKO_MODULES
                        Troubleshooting: generate Mako template modules in this
                        directory.
  --dry_run             Troubleshooting: displays work_order. Skips template generation and action scripts.
```

## Configuration

Before going into configuration and operational details, it is important to understand the base organization of the terraform and key terms:
- `[root]/` - The root directory for all Terraform configuration files.
- `[root]/[realm]` - Realm imples an AWS account. Ex.: "development", "production".
- `[root]/[realm]/global` - Resources that are global to a realm and/or shared amongst multiple environments, or shared across multiple accounts. For example, this contains the S3 `backend/`, which stores terraform state for the realm and all of its environments.  Other examples would be ECR repositories, shared IAM resources, Route53 zones, etc.
- `[root]/[realm]/[environment]` - Environment is a specific deployment of resources that can be separated from other environments under the same realm. This is where the majority of non-global, unshared resources go, such as EKS clusters. Ex.: "dev", "integration", "performance", "staging", "prod".

Example:
`../deployments/sandbox/lab`

### Realm configs
The realm configs are the source of truth for your realm configuration, including all realm environments.  These are merged with `defaults.yaml` in specific ways to produce a final configuration in memory.

Configuration is broadly split into:
- `globals` - variables and configs for `global` template resources, and/or shared variables required by all environment deployments.
- `environments` - Configurations for environment deployments
- `action_order` - Overrides the default order of operations for [bootstrap/plan/apply]/destroy actions.

Example:
`mycompany-[realm].yaml`
```yaml
globals:
  company: mycompany
  realm: demo
  region: us-west-2
  required_terraform_version: ">= 0.13.5"
  terraform_providers:
    aws:
      source: hashicorp/aws
      version: "3.35.0"
  zone_domains: ["demo.mycompany.com"] # optional
  outside_sub_domains: # optional
    lab.demo.mycompany.com:
      root_domain: demo.mycompany.com # must be present in zone_domains
      nameservers:
        - whatever.aws.com
        - whatever02.aws.com
        - whatever03.aws.com
        - whatever04.aws.com

environments:
# Each object listed under environments will be templated into separate environments named after the key.
  lab:
    # VPC configs
    vpc_domain_name: lab.demo.mycompany.com
    vpc_cidr: 10.1.0.0/16
    vpc_private_cidr: 10.1.0.0/20
    vpc_private_subnets:
      private_az_a:
        cidr: 10.1.0.0/24
        az_suffix: a
      private_az_b:
        cidr: 10.1.1.0/24
        az_suffix: b
      private_az_c:
        cidr: 10.1.2.0/24
        az_suffix: c
    vpc_public_cidr: 10.1.16.0/20
    vpc_public_subnets:
      public_az_a:
        cidr: 10.1.16.0/24
        az_suffix: a
      public_az_b:
        cidr: 10.1.17.0/24
        az_suffix: b
      public_az_c:
        cidr: 10.1.18.0/24
        az_suffix: c
    vpc_tags: {} # If not setting a dict or list, either set it to its respective empty version, or omit the parameter entirely.
    private_subnet_tags: {}
    public_subnet_tags: {}
    # DB Configs
    db_storage_size: 100
    db_max_allocated_storage: 1000
    db_instance_class: db.m5.large
    db_engine_version: "11.10"
    db_publicly_accesible: "false"
    db_skip_final_snapshot: "true"
    db_backup_retention_period: 7
    db_temp_password: TempPassword00!!
    db_password_encrypted: null # This is a special case.  See below.
    k8_clusters:
    # For each object listed here, an EKS cluster will be created.
      main:
        version: "1.17"
        node_groups:
        # For each object listed here, an EKS Node Group will be created for the parent cluster.
          default:
            capacity_type: "ON_DEMAND"
            public: "false"
            instance_types: ["m5.large"]
            min_nodes: 1
            max_nodes: 20
            desired_nodes: 20
            vol_size: 50
            vol_type: gp2
            node_tags: {}
            node_labels: {}
      argo:
        node_groups:
          spot:
            capacity_type: "SPOT"
            public: "true"
            instance_types:
              - m5.xlarge
              - m5n.xlarge
              - m5d.xlarge
              - m5dn.xlarge
              - m5a.xlarge
              - m4.xlarge
            min_nodes: 1
            max_nodes: 100
            desired_nodes: 20
            vol_size: 100
            vol_type: gp2
            node_tags:
              k8s.io/cluster-autoscaler/node-template/label/lifecycle: Ec2Spot
            node_labels:
              lifecycle: Ec2Spot
              aws.amazon.com/spot: "true"

action_order:
  apply:
    - global/backend
    - global/ecr
    - global/route53-zones-acm
    - global/route53-zones-acm/acm_validation
    - environments # expanded to each environment name

  destroy:
    - environments
    - global/route53-zones-acm/acm_validation
    - global/route53-zones-acm
    - global/ecr
```

#### Special configs
Some parameters require special instructions to configure:

- `outside_sub_domains` - This sets up subdomain NS records with a base zone domain configured in the realm.  For example, if the prod realm/account manages the `mycompany.com` domain, and you want to configure `dev.mycompany.com` for use in the dev account:
  1. Set up and apply `mycompany.com` in the `zone_domains` in the prod config.
  1. Set up `dev.mycompany.com` in the `zone_domains` in the dev config.
  1. Apply the terraform in the `mycompany/dev/global/route53-zones-acm` directory, and copy the NS records for the subdomain from the outputs.
  1. Then, update the prod config's `outside_sub_domains` with the following:
     ```yaml
     outside_sub_domains:
         dev.mycompany.com:
           root_domain: mycompany.com
           nameservers:
             - ns.aws.com
             - ns02.aws.com
             - ns03.aws.com
             - ns04.aws.com
     ```
     and apply prod.
  1. Eventually, once the ACM has been issued, re-apply dev's `route53-zones-acm`, then `route53-zones-acm/acm_validation` to validate the ACM.

- `db_password_encrypted` - This is the KMS encrypted db password.  Because the KMS key must be created before encrypting the password, this must be set to `null` when bootstrapping a new environment, and the db will be created with the `db_temp_password`.  After bootstrapping is complete, run the following command to encrypt a new password:
```bash
$ aws kms encrypt --output text --query CiphertextBlob --key-id "alias/${environment}-main" --plaintext $(echo -n "[password]" | base64)
```
(replace [password] with password and ${environment} with environment).  Once you have the encrypted password, set `db_password_encrypted`, re-generate the templates, and apply to update the RDS.


### Defaults
To save effort, there are a number of default settings in `defaults.yaml` that are selectively merged with the realm configs:
- defaults["globals"] - Merged with realm["globals"].
- defaults["environment_defaults"] - Merged with each realm["environments"]\[env].
- defaults["k8_defaults"] - Merged with each realm["environments"]\[env]\["k8_clusters"]\[cluster].
- defaults["node_group_defaults"] - Merged with each realm["environments"]\[env]\["k8_clusters"]\[cluster]\["node_groups"]\[node_group].
- defaults["action_order"] - Merged with realm["action_order"].

However, it is important to note that this is not a simple Python dict merge (or `.update()`), as doing so with empty nested structures in the realm configs would blow out the desired defaults. The exact procedure for each merge operation can be found in the `merge_defaults()` function in the script.

Here is an example of a shortened realm config that will be merged with default values:
```yaml
globals:
  company: mycompany
  realm: sandbox
  zone_domains: ["sandbox.mycompany.com"]
environments:
  lab: {}
  sandbox:
    vpc_domain_name: sandbox.mycompany.com
    public_subnet_tags:
      test: tag
    k8_clusters:
      main:
        node_groups:
          default: {}
      argo:
        node_groups:
          default: {}
          spot:
            capacity_type: "SPOT"
            public: true
            instance_types:
              - m5.xlarge
              - m5n.xlarge
              - m5d.xlarge
              - m5dn.xlarge
              - m5a.xlarge
              - m4.xlarge
            min_nodes: 1
            max_nodes: 100
            desired_nodes: 20
            vol_size: 100
            vol_type: gp2
            node_tags:
              k8s.io/cluster-autoscaler/node-template/label/lifecycle: Ec2Spot
            node_labels:
              lifecycle: Ec2Spot
              aws.amazon.com/spot: true
```

### action_order
`action_order` configures the default order of action script operations, so that dependencies are resolved and updated in the correct order.

IMPORTANT NOTES:
- All entries are appended to [root]/[realm]/
- `apply` list specifies the bootstrap, plan, and apply actions.
- Any item with the word `environments` will expand the realm config's "environments" config.  If there were "dev" and "prod" environments configured, that would resolve to [root]/[realm]/dev, and [root]/[realm]/prod.
- For the destroy action, you must leave out the `global/backend`, as Terraform still needs to store state if resources are being destroyed. If you wish to destroy the state bucket, you must do so manually.
- When "--target_env" is used, the apply section remains the same so that higher dependencies in the globals are resolved and updated first before executing the target environment configs.  However, for a similar reason, the destroy list is reduced to just entries containing "environments", in order to prevent the script from destroying global resources that other environments depend on.

## Operation
Details about how the script works

### Templates
This script uses Python `Mako` templates to generate the Terraform configs, bash scripts, and other files necessary for each realm and environment.  These are located in the `templates` folder.

#### Work Order
Before generating any templates or taking any actions, a `work_order` is compiled in memory.  The `work_order` maps each subdirectory under `templates`, expands environments, lists mako files to be templated and regular files to be copied, separately maps config variables from the realm configs for each subdirectory, and generates an action plan.

The templates folder and file structure map to the structure generated by the script.
- `global` - maps to [root]/[realm]/global
- `deployment` - maps to each configured environment.  For example, [root]/[realm]/dev, and [root]/[realm]/perf.

Any file with the extention .mako will be treated as a template, and the .mako extention will be removed.  Any other file will be copied as-is.

Each subfolder must be included in `action_order` configuration for actions to apply to it.

For `global` templates, realm_configs["globals"] is merged to root. `environments` and `action_order` keys are deleted, as they are not needed.

For `deployment` templates, realm_configs["globals"] is merged to root.  `deployment` is expanded to each environment in `environments`, and realm_configs["environments"][env] is merged to root for each environment.  This means that global overrides can be configured here for each environment. Also, root["environment"] is set to `env`, and `environments` and `action_order` are deleted.

For troubleshooting purposes, you may include the `--dry_run` flag to the command to view the proposed work order without generating any templates or taking any actions.
 

#### Best practices
- Avoid hard-coding values in resources. Place them in terraform variables, locals, outputs, etc, and refer to them using standard terraform syntax.
- Use modules wherever possible, and do not overly rely on templating to generate resource definitions. The eventual goal is to use modules for most of the terraform, and templates simply to set variables and bootstrap resources that cannot be modularized (like the S3 backend).
- Be careful when naming resources.  Avoid possible naming conflicts with other environments/resources, but also keep them generic enough to be applicable and consistent across other company/realm/environment configs.
- All dependencies should flow downward from globals to environments, and from parent directories to subdirectories.  Avoid creating circular dependencies from child to parent.  If necessary, use terraform `for_each` with `if` conditional that sets empty list or map if resource/output/config is not found.  See `templates/global/route53-zones-acm/acm_validation/locals.tf` as an example.
- To create new dynamic resources:
  - create new nested maps in the realm config yaml.
  - use a combination of mako `if`, `for`, and terraform `for_each` syntax in new templates to check for maps.  This will generate template code in a `for` loop, and utilize terraform `for_each` to create 0..n resources without error (making the resources optional).  See `templates/deployment/eks.tf.mako` for an example.
  - To utilize defaults, create a new defaults key for each dynamic level in `defaults.yaml`, and update `merge_defaults()` in `terraform-realm-utility.py` to intelligently merge the defaults into each realm config layer.

#### Troubleshooting
If templates are causing issues, set `--mako_modules` to a troubleshooting folder.

Now when templates are generated, the Python modules generated for each one are cached in this directory.  You may evaluate the code and compare to the traceback in order to troubleshoot any issues you are having.

**WARNING** - DO NOT CHECK IN THE MAKO MODULES DIRECTORY TO GIT!

### Actions
The `--action` argument has the following options:
- `bootstrap` - Bootstraps new realm/environments. Avoids state locking and other chicken/egg scenarios for new configs.
- `plan` - Runs terraform plan on all configured directories.  Good for running pre-commit MR pipeline actions to prevent faulty configs from being checked in.
- `apply` - Runs terraform apply on all configured directories.
- `destroy` - Runs terraform destroy on all configured directories.  **Will delete directories after destroying them.**

The script will exit if the `AWS_PROFILE` environment variable has not been set.

The order in which these are executed on each directory is determined by the `action_order` configuration mentioned earlier. 

The specified action executes a list of commands found in `defaults.yaml` - `default_actions[action]`.  **HOWEVER**, the default actions can be overridden if an {action}.sh script is found in the directory.  See `templates/globals/backend/bootstrap.sh.mako` as an example.

If `--target_env` is set, the `apply` actions will still execute the global resources first, as they hold resources each environment depends on.  However, it will only act on the target_env environment.  Counter to this, if the action is to `destroy` with `--target_env` set, it will skip the globals and ONLY destroy the target_env, as the globals are still required for other environments to function.

Running any action other than `plan` will prompt the user for confirmation.  **HOWEVER**, the script will skip confirmation if it does not have a tty (terminal) attached.  This is designed for running the script from a pipeline, although it will also apply if using cli nohup, redirection, or pipes (|).

**NEW TERRAFORM DIRS** When creating a new terraform config folder with a new backend state (such as creating a new environment), the `bootstrap` action **MUST** be run before attempting `apply` or `destroy`.  Keep this in mind when checking in new configs with a pipeline that automatically runs `apply`.  First `bootstrap` the new configuration directory before merging it.

**BOOTSTRAP** - The `bootstrap` action is idempotent and can be run multiple times on the same realms/environments.  The primary difference between this and `apply` (in most cases) is that `bootstrap` skips the state locking check, which makes it more dangerous to use if other people are applying terraform to the same backends at the same time.

`bootstrap` for the global backend, however, is more complicated.  If the backend bucket already exists, it runs a normal `apply` action.  Otherwise, it goes through a complex procedure to bootstrap a realm for the first time. See templates/global/backend/bootstrap.sh.mako.

**IMPORTANT** DO NOT include `global/backend` in destroy actions, as the backend is still required to store state regardless if all of the other configs are destroyed.  Remove this manually if you must, but it is not recommended.

To remove backend manually:
1. Empty the backend bucket from the console/cli, including all past versions of any files.
1. Delete the bucket.
1. Delete the backend state DynamoDB table.

## General Troubleshooting

Use the `--dry_run` flag with any other combination of arguments to display the `work_order`, which contains information on what folders are being targeted, what templates sources are being used, which mako template files are being generated vs. which regular files are being copied, what the merged config variables are for each folder, and what actions will be taken.  Using this flag will skip template generation along with any actions.

## Authors
- Garrett Anderson <ganderson@kdinfotech.com>
