#include "AlwaysOnAudit.h"
#include <bsm/libbsm.h>
#include <string.h>
int pane_audit_session(uint32_t asid, uint32_t *returned_asid, uint32_t *auid, uint64_t *flags) {
    auditinfo_addr_t info;
    memset(&info, 0, sizeof(info));
    info.ai_asid = (au_asid_t)asid;
    if (audit_get_sinfo_addr(&info, sizeof(info)) != 0) return -1;
    *returned_asid = (uint32_t)info.ai_asid;
    *auid = info.ai_auid;
    *flags = info.ai_flags;
    return 0;
}
