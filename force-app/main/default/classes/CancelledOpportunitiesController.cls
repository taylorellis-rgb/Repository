public with sharing class CancelledOpportunitiesController {

    private static final Set<String> CANCELLED_STAGES = new Set<String>{
        'Closed Lost', 'Cancelled'
    };

    /**
     * Returns all opportunities in a cancelled stage along with
     * the date/time the stage was last changed to that status,
     * who made the change, and what the previous stage was.
     */
    @AuraEnabled(cacheable=true)
    public static List<OpportunityWrapper> getCancelledOpportunities() {
        List<Opportunity> cancelledOpps = [
            SELECT Id, Name, StageName, CloseDate, Amount,
                   Account.Name, Owner.Name
            FROM Opportunity
            WHERE StageName IN :CANCELLED_STAGES
            ORDER BY CloseDate DESC
            LIMIT 2000
        ];

        if (cancelledOpps.isEmpty()) {
            return new List<OpportunityWrapper>();
        }

        Set<Id> oppIds = new Map<Id, Opportunity>(cancelledOpps).keySet();

        // Build a map of oppId -> ordered history list (ASC by date)
        // OpportunityHistory records one entry per stage transition.
        Map<Id, List<OpportunityHistory>> historyByOpp = new Map<Id, List<OpportunityHistory>>();
        for (Id oppId : oppIds) {
            historyByOpp.put(oppId, new List<OpportunityHistory>());
        }

        for (OpportunityHistory hist : [
            SELECT Id, OpportunityId, StageName, CreatedDate, CreatedBy.Name
            FROM OpportunityHistory
            WHERE OpportunityId IN :oppIds
            ORDER BY OpportunityId, CreatedDate ASC
        ]) {
            historyByOpp.get(hist.OpportunityId).add(hist);
        }

        List<OpportunityWrapper> result = new List<OpportunityWrapper>();
        for (Opportunity opp : cancelledOpps) {
            OpportunityWrapper wrapper = new OpportunityWrapper();
            wrapper.id = opp.Id;
            wrapper.name = opp.Name;
            wrapper.stageName = opp.StageName;
            wrapper.closeDate = opp.CloseDate;
            wrapper.amount = opp.Amount;
            wrapper.accountName = opp.Account != null ? opp.Account.Name : null;
            wrapper.ownerName = opp.Owner.Name;
            wrapper.opportunityUrl = '/' + opp.Id;

            List<OpportunityHistory> history = historyByOpp.get(opp.Id);
            if (history != null && !history.isEmpty()) {
                // Walk backwards to find the most recent transition into a cancelled stage
                for (Integer i = history.size() - 1; i >= 0; i--) {
                    if (CANCELLED_STAGES.contains(history[i].StageName)) {
                        wrapper.cancelledDate = history[i].CreatedDate;
                        wrapper.cancelledBy = history[i].CreatedBy.Name;
                        if (i > 0) {
                            wrapper.previousStage = history[i - 1].StageName;
                        }
                        break;
                    }
                }
            }

            result.add(wrapper);
        }

        return result;
    }

    public class OpportunityWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String stageName { get; set; }
        @AuraEnabled public Date closeDate { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public String opportunityUrl { get; set; }
        @AuraEnabled public DateTime cancelledDate { get; set; }
        @AuraEnabled public String cancelledBy { get; set; }
        @AuraEnabled public String previousStage { get; set; }
    }
}
