---
name: Access Termination
about: Revoke someone's access when they leave MMW or change role. File it in mark-my-work/mmw-hr.
title: 'Revoke access for [person]'
labels: hr
---

<!-- Set the issue TYPE to **Task** in the issue UI (a Type chosen in the sidebar, not a label). Replace [person]
     in the title with the person's name, and set the issue's Priority on the MMW board to match how soon
     their last working day is. -->

**Mark My Work – Access Termination Checklist**

Version 1.2 – November 2026 – supports "MMW ISMS-04" and "MMW ISMS-21"

- Complete the checklist whenever an employee, contractor, advisor or tester leaves MMW or their engagement ends. For a change of role, use Section 3 to remove only the access the new role no longer needs.
- Revoke access on the last working day – do not wait for the next quarterly access review. Set the issue's priority to match how soon that is.
- Tick each item when it is done (see Section 3), and add any proof as a comment on this issue that starts with the item's number – the record or setting checked, and who did it if not the person commenting. GitHub records who commented and when.
- The CTO, as Security Officer, completes the checklist. The CPO, as Privacy Officer, confirms the personal information items.
- The closed issue is the completed checklist.
- The CTO follows up any item not yet ticked until it is done. Access found still active is removed at once.
- At the next Quarterly MMW Officers Meeting, confirm in the access review that no account for the person remains active.
- Raise a nonconformity under "MMW ALL-10" if access was not removed on time, and an incident under "MMW ISMS-13" if MMW data or personal information may have been retained or exposed.

## 1. Purpose and Use

This checklist records the removal of a departing person's access to Mark My Work (MMW) systems and data, and the return of MMW assets. It follows the leaving process in "MMW ISMS-04 – Access Control Policy" and the offboarding process in "MMW ISMS-21 – HR Security Procedures". The completed checklist, together with the access register, is the audit evidence that access was removed on time (Annex A controls 5.11, 5.18 and 6.5).

The MMW documents referred to in this checklist are in the [Management Systems](https://vannikca.sharepoint.com/:f:/r/sites/MMW-AllEmployees/Shared%20Documents/Management%20Systems?d=w5e52b23549974a1e8edec496bdd66f78&csf=1&web=1&e=8PmgUA) folder in SharePoint.

## 2. Person Details

- **Name:**
- **Role / Engagement:** *e.g. employee, contractor, advisor, tester*
- **Engaging Officer:**
- **Last Working Day:**
- **Access to Personal Information:** *Yes / No – from the access register*

## 3. Checklist

References are to MMW documents (e.g. "ISMS-04 §3" is "MMW ISMS-04", Section 3).

Mark each item as follows. After filing, ticking boxes is all the issue needs; proof goes in comments.

- **To do** – the box is clear. If an item is held up, comment with what remains, and who will finish it if not the issue's assignee.
- **Done** – tick the box, and add any proof as a comment that starts with the item's number.
- **N/A** – the item does not apply to this person (e.g. no AWS access). When filing, tick the box and add *(N/A)* at the end of the item; item 2's list of the person's access shows why.

### A. Before Revoking Access

- [ ] **1.** The CTO has been notified of the departure and last working day of the departing employee (e.g. e-mail to security@markmywork.ca).
- [ ] **2.** Before filing, the person's current access has been looked up in the access register, so that the checklist below covers every account the person has access to: items that do not apply are marked N/A, and item 9 has a sub-item for any account the checklist does not already cover. Once the issue is filed, the list is added as a comment.

### B. Revoke Access (in this order)

- [ ] **3.** AWS – IAM Identity Center user disabled and removed from all groups; any open Session Manager sessions ended; production database roles and the transcripts bucket confirmed removed.
- [ ] **4.** GitHub – removed from the MMW organisation; any deploy keys or tokens the person created removed.
- [ ] **5.** Microsoft 365, SharePoint and Teams – sign-in blocked and active sessions revoked.
- [ ] **6.** 1Password – removed from all vaults and the account removed.
- [ ] **7.** Third-party consoles – removed from each one the person has access to. Tick this item when every console below is ticked.
  - [ ] Anthropic
  - [ ] Stripe
  - [ ] Sentry
  - [ ] Domain registrar / DNS
- [ ] **8.** Application administrative functions used to support teacher accounts – access removed.
- [ ] **9.** Other access – one sub-item for each account on item 2's list that items 3–8 don't cover. Tick this item when every sub-item is ticked, or mark it N/A if there are none.

### C. Credentials and Keys

- [ ] **10.** Every shared credential the person could have seen (e.g. in 1Password) has been rotated.
- [ ] **11.** Every API key or secret the person had access to (Anthropic, Stripe, Sentry, `mmw/*` secrets) has been replaced, and the rotation date recorded.

### D. Devices and Data

- [ ] **12.** Company devices returned and updated in the asset inventory.
- [ ] **13.** Returned devices wiped (encryption key destroyed and factory reset) before reuse or disposal.
- [ ] **14.** Approved personal device – MMW accounts removed and, where supported, MMW data remote-wiped through Microsoft 365.
- [ ] **15.** Toronto office keys or building access card returned.
- [ ] **16.** The person confirms that no MMW data, and no personal information, remains on a personal device or personal account (confirmed by the CPO where the person had personal information access; requires written / e-mail confirmation).

### E. Obligations and Records

- [ ] **17.** The person has been reminded that the confidentiality and privacy obligations in their NDA continue after departure (requires written / e-mail confirmation).
- [ ] **18.** Officer or manager departures – responsibilities reassigned and "MMW ALL-06" updated.
- [ ] **19.** Access register updated with the removal date for every account.

## 4. Sign-Off

- **Completed by (CTO):** the CTO closes this issue as completed. GitHub records the name and date.
- **Personal information items confirmed (CPO):** the CPO comments on this issue "Personal information items confirmed." GitHub records the name and date.
