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

Version 1.1 – November 2026 – supports "MMW ISMS-04" and "MMW ISMS-21"

- Complete the checklist whenever an employee, contractor, advisor or tester leaves MMW or their engagement ends. For a change of role, use Section 3 to remove only the access the new role no longer needs.
- Revoke access on the last working day – do not wait for the next quarterly access review. Set the issue's priority to match how soon that is.
- For each item, update the status on the line under it (see Section 3) and note the evidence – the date, the record or setting checked, and who did it if not the issue's assignee.
- The CTO, as Security Officer, completes the checklist. The CPO, as Privacy Officer, confirms the personal information items.
- The closed issue is the completed checklist.
- The CTO follows up any Open item until it is Done. Access found still active is removed at once.
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

Each item starts as Open. Change the status on the line under it to one of the following:

- **Done** – the action is complete, with the date and evidence noted, and who did it if not the issue's assignee. Tick the box.
- **Open** – the action is not yet complete, with what remains, and who will finish it if not the issue's assignee. Leave the box clear.
- **N/A** – the item does not apply to this person (e.g. no AWS access), with the reason noted. Tick the box.

### A. Before Revoking Access

- [ ] **1.** The CTO has been notified of the departure and last working day of the departing employee (e.g. e-mail to security@markmywork.ca).
  Open
- [ ] **2.** The person's current access has been looked up in the access register and listed here, so that the checklist below covers every account the person has access to. Add a sub-item to item 9 for any account the checklist does not already cover.
  Open

### B. Revoke Access (in this order)

- [ ] **3.** AWS – IAM Identity Center user disabled and removed from all groups; any open Session Manager sessions ended; production database roles and the transcripts bucket confirmed removed.
  Open
- [ ] **4.** GitHub – removed from the MMW organisation; any deploy keys or tokens the person created removed.
  Open
- [ ] **5.** Microsoft 365, SharePoint and Teams – sign-in blocked and active sessions revoked.
  Open
- [ ] **6.** 1Password – removed from all vaults and the account removed.
  Open
- [ ] **7.** Third-party consoles – removed from each one the person has access to. Tick this item when every console below is Done or N/A.
  - [ ] Anthropic
    Open
  - [ ] Stripe
    Open
  - [ ] Sentry
    Open
  - [ ] Domain registrar / DNS
    Open
- [ ] **8.** Application administrative functions used to support teacher accounts – access removed.
  Open
- [ ] **9.** Other access – one sub-item for each account on item 2's list that items 3–8 don't cover. Tick this item when every sub-item is Done or N/A, or mark it N/A if there are none.
  Open

### C. Credentials and Keys

- [ ] **10.** Every shared credential the person could have seen (e.g. in 1Password) has been rotated.
  Open
- [ ] **11.** Every API key or secret the person had access to (Anthropic, Stripe, Sentry, `mmw/*` secrets) has been replaced, and the rotation date recorded.
  Open

### D. Devices and Data

- [ ] **12.** Company devices returned and updated in the asset inventory.
  Open
- [ ] **13.** Returned devices wiped (encryption key destroyed and factory reset) before reuse or disposal.
  Open
- [ ] **14.** Approved personal device – MMW accounts removed and, where supported, MMW data remote-wiped through Microsoft 365.
  Open
- [ ] **15.** Toronto office keys or building access card returned.
  Open
- [ ] **16.** The person confirms that no MMW data, and no personal information, remains on a personal device or personal account (confirmed by the CPO where the person had personal information access; requires written / e-mail confirmation).
  Open

### E. Obligations and Records

- [ ] **17.** The person has been reminded that the confidentiality and privacy obligations in their NDA continue after departure (requires written / e-mail confirmation).
  Open
- [ ] **18.** Officer or manager departures – responsibilities reassigned and "MMW ALL-06" updated.
  Open
- [ ] **19.** Access register updated with the removal date for every account.
  Open

## 4. Sign-Off

- **Completed by (CTO):** the CTO closes this issue as completed. GitHub records the name and date.
- **Personal information items confirmed (CPO):** the CPO comments on this issue "Personal information items confirmed." GitHub records the name and date.
