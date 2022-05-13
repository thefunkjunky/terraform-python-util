variable "region" { default = "${region}" }

variable "zone_domains" {
  default = [
    % for domain in zone_domains:
    "${domain}",
    % endfor 
  ]
}

variable "outside_sub_domains" {
  description = "Outside subdomains to create NS records for"
  default = {
  % if outside_sub_domains:
  % for subdomain, config in outside_sub_domains.items():
    "${subdomain}" = {
      "root_domain" = "${config["root_domain"]}"
      "nameservers" = [
        % for ns in config["nameservers"]:
          "${ns}",
        % endfor
      ]
    },
  % endfor
  % endif
  }
}
