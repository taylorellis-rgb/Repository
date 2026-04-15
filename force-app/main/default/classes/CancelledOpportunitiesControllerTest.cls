@IsTest
private class CancelledOpportunitiesControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Test Account Corp');
        insert acc;

        // Create opportunities starting in an open stage
        List<Opportunity> opps = new List<Opportunity>{
            new Opportunity(
                Name = 'Cancelled Deal Alpha',
                AccountId = acc.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                Amount = 25000
            ),
            new Opportunity(
                Name = 'Active Deal Beta',
                AccountId = acc.Id,
                StageName = 'Proposal/Price Quote',
                CloseDate = Date.today().addDays(60),
                Amount = 50000
            ),
            new Opportunity(
                Name = 'Cancelled Deal Gamma',
                AccountId = acc.Id,
                StageName = 'Value Proposition',
                CloseDate = Date.today().addDays(15),
                Amount = 10000
            )
        };
        insert opps;

        // Transition two opportunities to a cancelled stage, creating OpportunityHistory records
        opps[0].StageName = 'Closed Lost';
        opps[2].StageName = 'Closed Lost';
        update new List<Opportunity>{ opps[0], opps[2] };
    }

    @IsTest
    static void testGetCancelledOpportunities_ReturnsOnlyCancelledStages() {
        Test.startTest();
        List<CancelledOpportunitiesController.OpportunityWrapper> results =
            CancelledOpportunitiesController.getCancelledOpportunities();
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return exactly 2 cancelled opportunities');

        Set<String> names = new Set<String>();
        for (CancelledOpportunitiesController.OpportunityWrapper w : results) {
            names.add(w.name);
            System.assertEquals('Closed Lost', w.stageName, 'Stage should be Closed Lost for: ' + w.name);
            System.assertNotEquals(null, w.opportunityUrl, 'URL should not be null for: ' + w.name);
        }

        System.assert(names.contains('Cancelled Deal Alpha'), 'Results should include Cancelled Deal Alpha');
        System.assert(names.contains('Cancelled Deal Gamma'), 'Results should include Cancelled Deal Gamma');
        System.assert(!names.contains('Active Deal Beta'), 'Active Deal Beta should not be included');
    }

    @IsTest
    static void testGetCancelledOpportunities_PopulatesCancellationHistory() {
        Test.startTest();
        List<CancelledOpportunitiesController.OpportunityWrapper> results =
            CancelledOpportunitiesController.getCancelledOpportunities();
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return 2 records');

        for (CancelledOpportunitiesController.OpportunityWrapper w : results) {
            System.assertNotEquals(
                null, w.cancelledDate,
                'cancelledDate should be populated from OpportunityHistory for: ' + w.name
            );
            System.assertNotEquals(
                null, w.cancelledBy,
                'cancelledBy should be populated from OpportunityHistory for: ' + w.name
            );
        }
    }

    @IsTest
    static void testGetCancelledOpportunities_PopulatesPreviousStage() {
        Test.startTest();
        List<CancelledOpportunitiesController.OpportunityWrapper> results =
            CancelledOpportunitiesController.getCancelledOpportunities();
        Test.stopTest();

        // Find the Alpha opportunity (was in Prospecting before Closed Lost)
        for (CancelledOpportunitiesController.OpportunityWrapper w : results) {
            if (w.name == 'Cancelled Deal Alpha') {
                System.assertEquals(
                    'Prospecting', w.previousStage,
                    'Previous stage for Alpha should be Prospecting'
                );
            }
            if (w.name == 'Cancelled Deal Gamma') {
                System.assertEquals(
                    'Value Proposition', w.previousStage,
                    'Previous stage for Gamma should be Value Proposition'
                );
            }
        }
    }

    @IsTest
    static void testGetCancelledOpportunities_PopulatesAccountAndOwner() {
        Test.startTest();
        List<CancelledOpportunitiesController.OpportunityWrapper> results =
            CancelledOpportunitiesController.getCancelledOpportunities();
        Test.stopTest();

        for (CancelledOpportunitiesController.OpportunityWrapper w : results) {
            System.assertEquals('Test Account Corp', w.accountName, 'Account name should be populated');
            System.assertNotEquals(null, w.ownerName, 'Owner name should be populated');
        }
    }

    @IsTest
    static void testGetCancelledOpportunities_ReturnsEmptyListWhenNoneExist() {
        delete [SELECT Id FROM Opportunity];

        Test.startTest();
        List<CancelledOpportunitiesController.OpportunityWrapper> results =
            CancelledOpportunitiesController.getCancelledOpportunities();
        Test.stopTest();

        System.assertNotEquals(null, results, 'Result list should never be null');
        System.assertEquals(0, results.size(), 'Should return an empty list');
    }
}
