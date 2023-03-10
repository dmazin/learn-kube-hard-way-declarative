# Kubernetes the hard way in Terraform
### 7 Jan 2023
A couple days ago, I read Learn Kubernetes the Hard Way, and generally read about the architecture of Kubernetes. I also brushed up on Terraform. Starting today, I want to solidify these two adventures by implementing Learn Kubernetes the Hard Way using Terraform, Ansible, Kustomize (or Helm) and otherwise making it more of a repeatable, idempotent process.

First, I will create a new project. I will not do this using Terraform, even though technically I could (within an organization). It's a fair bit of work, and it's a relatively rare thing to need to do.

First, I'm going to make a .env file so that I can store some frequently used terms and can load them later. For example, in that file I will put...

```
export project_name=learn-kube-hard-way-dmazin
```

That way I can `source .env` later to load my env vars.

Anyway, create the project. This step is not idempotent since project names must be globally unique.
    
```
gcloud projects create $project_name
```

And switch to the project.
```
gcloud config set project $project_name
```

Alrighty, now on to the TF config. First, we [configure some networking](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md#virtual-private-cloud-network).

I don't know yet how I will organize the TF directory – this is something I want to get better at. For now, I will stick networking-related stuff in a folder called networking.

Oh, one more thing. While I could define resources in Terraform directly, a nifty thing I saw a coworker do is extensivley use public modules vendored by Google. For example, [this module](https://registry.terraform.io/modules/terraform-google-modules/network/google/latest) lets you create networking stuff. (I might come to regret this... I'm not sure. I'm not terribly worried about losing out on learning, because I've created plenty of networking resources using TF. What I'm more worried about is that the modules will do far more than I need, and I'll struggle to fit them to my usecase. We'll see).

Oh, right. First, I need to create a service account + key and grant it `roles/editor`. You will find that in `bootstrap_service_account.sh`. Also, as I go along, I will need to enable various APIs via clickops.

OK, here we go. Let's define the VPC and subnet. You will find that under commit 6a7b4f64847bc97a8cdbb12c65362a0c1d161e3c.

(I tried to apply that, and at this point I needed to enable the compute API).

OK, network and subnet created (see commit 71e0629). One thing I learned: the docs for the Google modules are nearly useless; refer to the module file itself to learn how to use it.

Now, I will create the [firewall rules](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md#firewall-rules).

MAJOR VICTORY!!! When creating the firewall, I need to refer to the subnet CIDRs of the subnets I want to apply the firewall rule to. I found out how to do it dynamically!

The subnet module outputs the created subnets. I used `terraform console` to play around with the returned values, and then found that I can simply use a list comprehension to loop over the outputs: `[for s in module.subnets.subnets: s.ip_cidr_range]`.

Wee! I feel great. My firewall rules match the output in Learn Kubernetes the Hard Way. See commit 2bb2eaa. Wrapping up for the day.

### 7 Jan 2023
I'm so excited about this project that I woke up on a Saturday morning to continue working on it. :-) I think Eamon will sleep in for another 20 mins, at least.

The next step is to [allocate a public IP address](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md#kubernetes-public-ip-address). Done: see commit df108a4.

Next up: [creating the VMs](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md#compute-instances) but Eamon is up.


### 9 Jan 2023
The [TF module for VMs](https://github.com/terraform-google-modules/terraform-google-vm/tree/master/modules/compute_instance) seems to force you to create a template, and only from that template you can create VMs. That is just fine with me. It forces a little DRYness. This is not really a challenge. The challenge is converting the command-line arguments to the declarative form (I mean, that is the point of this entire project, but I am now running into a bit where I'm not super clear what to do next.) Here is how Hightower creates the control plane VMs.

- [ ] Oh wait, one TODO before I forget: when [creating the kubernetes-the-hard-way-allow-internal firewall rule](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md#firewall-rules), Hightower adds `10.200.0.0/16` to the source range which I did not. This is the range for the pods themselves; for some reason he does not actually create a subnet. I am not adding this yet, but I do wonder if maybe I should just create a subnet for tidiness.

Anyway, back to the VMs. Here is how Hightower creates them.
```bash
for i in 0 1 2; do
  gcloud compute instances create controller-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image-family ubuntu-2004-lts \
    --image-project ubuntu-os-cloud \
    --machine-type e2-standard-2 \
    --private-network-ip 10.240.0.1${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-hard-way,controller
done
```

These are the flags I don't understand.
- can-ip-forward
- scopes

The scopes trip me up because I am not sure at all what they are. How do they relate to service account roles? What are these? `--help` is unclear. What about the docs? OK, here's what the docs have to say.
> Access scopes are the legacy method of specifying authorization for your instance.

OK.

> IAM restricts access to APIs based on the IAM roles that are granted to the service account.
> Access scopes potentially further limit access to API methods.

And...

> The best practice is to set the full cloud-platform access scope on the instance, then control the service account's access using IAM roles.

OK, so I understand scopes now. Scopes apply to VMs. They relate to OAuth, which is why they're called scopes. They control the requests made by the gcloud CLI and client libs running on the VM. But they do not affect gRPCs (I guess because they are legacy). The way they relate to IAM roles is that they are the older form of authorization.

A decision: should I just use scopes, and come back to it later, or should I improve? I want to improve. That way if someone actually reads my work, they are learning best practices. I just have to figure out what roles the scopes map to.

The scopes: `compute-rw,storage-ro,service-management,service-control,logging-write,monitoring`

Man, the documentation for these is non-existent. Does `compute-rw` mean that the instance is able to create/edit compute resources? That's a little surprising. I don't think we'd want that. Here is the crux: because I don't know the goal of the scopes, and because there is no documented scope-to-role mapping, I don't know what roles to use.

But I can kind of bluster my way through this. The intent of logging-write,monitoring is clear enough, and I'll figure out what roles it maps to. For the other scopes, I simply will pass over them, and if I am unable to do something in the future due to a permissions issue, I'll be able to add the new permission thanks to the error message.

For monitoring, I think the important thing is that the compute instances need to be able to write metrics, so I'll grant [roles/monitoring.metricWriter](https://cloud.google.com/iam/docs/understanding-roles#monitoring.metricWriter). For logging, I'll grant [roles/logging.logWriter](https://cloud.google.com/iam/docs/understanding-roles#logging.logWriter).

Oh, by the way, I can tell what role the storage-ro access scope might map to, but I do not understand why the instances might need it. So I'll leave it for now. Also, I am sure that the instances will need some compute roles – we'll see. And, finally, I did figure out that the service-management and service-control scopes map to [these roles](https://cloud.google.com/service-infrastructure/docs/service-management/access-control).

Of course, the other thing I need to do is create the service accounts used by the VMs.

A TODO:
- [ ] Rename the project var to project_id. This is the real name of the thing I'm referring to: it's the ID. It's unique across GCP.

OK, I am failing to create the service accounts and assign the roles to it. I think that is probably because my service account is an editor, not an owner. I will make it an owner. (See commit df7b017). Yep, that did the trick! SA created.

I'll be able to use this SA (call it control-plane) when creating the instance template. On to that...

Interesting. So, I want to reference the control-plane SA (which I defined in the iam/ dir) in the VM template (which I defined in the vms/ dir). Turns out, this is tricky. Well, not tricky. It's just something one must think about. There is no way to pass the output of one directory to another. However, I can do two things: flatten the structure, so that there are no directories – only files. Or, I can import the info I need as `data` blocks.

In fact, I think that I should get rid of my directory structure and replace it with files. Only the `main.tf` files vary between my dirs, and so repeating the other files (e.g. variables.tf) is senseless. I will just use different files.

Ah, of course, I have a set of TF state for each directory. I have no idea how to merge it, and there is little benefit to trying. I will just destroy everything and start over. Thank you `tf destroy`!

Cool, I now have a flat structure. (see commit 144c765).

(Some wrangling later) Yay! I have the controller instances running and I can SSH into them! (See commit a10f0d3)

### 16 Jan 2023

Lots of time has passed. Thanks to these notes, I know where I left off. I think where I want to continue is to finish out all the Terraform steps before moving on to any Ansible stuff.

So, next I need to provision the nodes. Ah.. actually, I am super curious how we can make Ansible SSH into the instances without creating special SSH keys. Can it use IAP somehow? So, next I'm going to read about best practices for SSH against a VM.

Sounds like [OS Login](https://cloud.google.com/compute/docs/oslogin) is "the recommended way to manage many users across multiple instances or projects". Which honestly describes any realistic project.

Here's [how to enable OS login when creating an instance](https://cloud.google.com/compute/docs/oslogin/set-up-oslogin#enable_os_login_during_vm_creation).

I am now reading [this tutorial on using OS login with Ansible](https://alex.dzyoba.com/blog/gcp-ansible-service-account/).

However, I want to say that I got Ansible inventory to work!

```
-> % ansible-inventory --list -i gcp_compute.yaml | jq "._meta.hostvars[].name"
"controller-001"
"controller-002"
"controller-003"
"worker-001"
"worker-002"
"worker-003"
```

Anyway, now I need to do OS login for Ansible. I need to set up a separate SA for Ansible, and assign it [the right roles](https://cloud.google.com/compute/docs/oslogin/set-up-oslogin) as well as enable an OS login ssh key for it. I'm going to see if giving the SA `roles/compute.osLogin` will make logins work.

Damn, I wanted to do this, but unfortunately, you need to be auth'ed as the SA you're uploading the key for. So this bit will have to happen via gcloud CLI.
# resource "google_os_login_ssh_public_key" "cache" {
#   user = module.service_account_ansible.service_account.email
#   key  = file("../ansible/ssh-key-ansible-sa.pub")
# }

```
│ Error: Error creating SSHPublicKey: googleapi: Error 403: End user credentials must match the user specified in the request. Request for user [ ansible@learn-kube-hard-way-dmazin.iam.gserviceaccount.com] does not match the credential for [owner-sa@learn-kube-hard-way-dmazin.iam.gserviceaccount.com].
```

Here's how. (These are quick-and-dirty steps; I'll need to clean them up later [i.e. store the key not in the cwd])
1. Generate the key...: `ssh-keygen -f ssh-key-ansible-sa`
2. Impersonate the account
3. Upload the key

(These are from the OS login with Ansible blog post)

Anyway, after that actually login still doesn't work:
```
ERROR: (gcloud.compute.start-iap-tunnel) Error while connecting [4033: 'not authorized'].
kex_exchange_identification: Connection closed by remote host
Connection closed by UNKNOWN port 65535
```

It might be because I need to assign more roles to th SA. Not sure!

Hmm, I gave the Ansible SA the `roles/iam.serviceAccountUser` role for the VM SA, but still no luck. Weird! According to the docs it should work now.

I'm going to see what happens when I also add `roles/viewer` to the Ansible SA, even though I don't think this should be necessary.

No, that did not help. I'll remove the binding.

My last guess is that perhaps the VM has more than one SA.

Hmm, no... that is the only SA used by that VM.

OK, next time, I think. It's 16:43. Maybe I need to twiddle with the SSH key or something.

Does SSHing as the owner SA work? Yes, it does! So it's a permissions thing.

Out of curiosity, what if I assign the `roles/compute.osAdminLogin` role instead? (Actually I'll need to use this role anyway since the Ansible playbooks will involve sudo shit)

Nah, still doesn't work. Actually looking at the error, I think maybe I need to enable another permission for IAP tunnelling:
```
ERROR: (gcloud.compute.start-iap-tunnel) Error while connecting [4033: 'not authorized'].
kex_exchange_identification: Connection closed by remote host
```

Maybe I need to grant [roles/iap.tunnelResourceAccessor](https://cloud.google.com/iap/docs/managing-access#iap.tunnelResourceAccessor).

Damn, still doesn't work! Crazy!

I just looked at the Ansible article again, and these are the roles they set.
```
    'roles/compute.instanceAdmin' \
    'roles/compute.instanceAdmin.v1' \
    'roles/compute.osAdminLogin' \
    'roles/iam.serviceAccountUser'
```

Well, I'm only setting two of these. Let me see if things work if I also set instanceAdmin.

That worked! Huh, I wonder why that isn't mentioned in the OS Login docs. What permissions does this grant? Well, [tons](https://cloud.google.com/compute/docs/access/iam). But clearly whatever the SA needs, it's not a read-only permission, because I tried granting it `roles/viewer` before and that wasn't enough.

OK, I can live with the Ansible account having `roles/compute.instanceAdmin`. I guess even on a project level. This is definitely one of those things that I think needs improvement.

(For the record, I've been logging in with `gcloud compute ssh worker-001`)

So, having done all this, funny enough this is *not* how we will login. Ansible will use regular old ssh. That is why we need to upload keys.