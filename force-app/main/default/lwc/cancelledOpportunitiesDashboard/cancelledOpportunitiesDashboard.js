import { LightningElement, track, wire } from 'lwc';
import getCancelledOpportunities from '@salesforce/apex/CancelledOpportunitiesController.getCancelledOpportunities';

const COLUMNS = [
    {
        label: 'Opportunity Name',
        fieldName: 'opportunityUrl',
        type: 'url',
        sortable: true,
        typeAttributes: { label: { fieldName: 'name' }, target: '_blank' }
    },
    {
        label: 'Account',
        fieldName: 'accountName',
        type: 'text',
        sortable: true
    },
    {
        label: 'Amount',
        fieldName: 'amount',
        type: 'currency',
        sortable: true,
        typeAttributes: { minimumFractionDigits: 0, maximumFractionDigits: 0 },
        cellAttributes: { alignment: 'left' }
    },
    {
        label: 'Close Date',
        fieldName: 'closeDate',
        type: 'date-local',
        sortable: true,
        typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' }
    },
    {
        label: 'Stage',
        fieldName: 'stageName',
        type: 'text',
        sortable: true
    },
    {
        label: 'Cancelled Date',
        fieldName: 'cancelledDate',
        type: 'date',
        sortable: true,
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }
    },
    {
        label: 'Changed By',
        fieldName: 'cancelledBy',
        type: 'text',
        sortable: true
    },
    {
        label: 'Previous Stage',
        fieldName: 'previousStage',
        type: 'text',
        sortable: true
    },
    {
        label: 'Owner',
        fieldName: 'ownerName',
        type: 'text',
        sortable: true
    }
];

export default class CancelledOpportunitiesDashboard extends LightningElement {
    @track filteredData = [];

    data = [];
    error;
    isLoading = true;

    searchTerm = '';
    filterStartDate = '';
    filterEndDate = '';
    filterStage = 'All';
    sortedBy = 'cancelledDate';
    sortedDirection = 'desc';

    columns = COLUMNS;

    stageOptions = [
        { label: 'All Stages', value: 'All' },
        { label: 'Closed Lost', value: 'Closed Lost' },
        { label: 'Cancelled', value: 'Cancelled' }
    ];

    @wire(getCancelledOpportunities)
    wiredOpportunities({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.data = data.map(opp => ({ ...opp }));
            this.error = undefined;
            this.applyFilters();
        } else if (error) {
            this.error = error?.body?.message || 'An unexpected error occurred while loading opportunities.';
            this.data = [];
            this.filteredData = [];
        }
    }

    get hasRecords() {
        return this.filteredData.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.error && this.filteredData.length === 0;
    }

    get totalCount() {
        return this.data.length;
    }

    get filteredCount() {
        return this.filteredData.length;
    }

    get totalAmountFormatted() {
        const total = this.filteredData.reduce((sum, opp) => sum + (opp.amount || 0), 0);
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(total);
    }

    get lastCancelledDateFormatted() {
        const withDates = this.data.filter(o => o.cancelledDate);
        if (!withDates.length) return 'N/A';
        const latest = withDates.reduce((prev, curr) =>
            new Date(curr.cancelledDate) > new Date(prev.cancelledDate) ? curr : prev
        );
        return new Intl.DateTimeFormat('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        }).format(new Date(latest.cancelledDate));
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
        this.applyFilters();
    }

    handleStartDateChange(event) {
        this.filterStartDate = event.target.value;
        this.applyFilters();
    }

    handleEndDateChange(event) {
        this.filterEndDate = event.target.value;
        this.applyFilters();
    }

    handleStageChange(event) {
        this.filterStage = event.detail.value;
        this.applyFilters();
    }

    applyFilters() {
        let filtered = [...this.data];

        if (this.searchTerm) {
            const term = this.searchTerm.toLowerCase();
            filtered = filtered.filter(opp =>
                opp.name?.toLowerCase().includes(term) ||
                opp.accountName?.toLowerCase().includes(term)
            );
        }

        if (this.filterStage !== 'All') {
            filtered = filtered.filter(opp => opp.stageName === this.filterStage);
        }

        if (this.filterStartDate) {
            const startDate = new Date(this.filterStartDate);
            filtered = filtered.filter(opp =>
                opp.cancelledDate && new Date(opp.cancelledDate) >= startDate
            );
        }

        if (this.filterEndDate) {
            const endDate = new Date(this.filterEndDate);
            endDate.setHours(23, 59, 59, 999);
            filtered = filtered.filter(opp =>
                opp.cancelledDate && new Date(opp.cancelledDate) <= endDate
            );
        }

        this.filteredData = this.sortData(filtered, this.sortedBy, this.sortedDirection);
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        this.filteredData = this.sortData([...this.filteredData], this.sortedBy, this.sortedDirection);
    }

    sortData(data, field, direction) {
        const multiplier = direction === 'asc' ? 1 : -1;
        return [...data].sort((a, b) => {
            // URL columns: sort by the display label (name) instead
            const aVal = field === 'opportunityUrl' ? (a.name || '').toLowerCase()
                       : typeof a[field] === 'string' ? a[field].toLowerCase()
                       : a[field];
            const bVal = field === 'opportunityUrl' ? (b.name || '').toLowerCase()
                       : typeof b[field] === 'string' ? b[field].toLowerCase()
                       : b[field];

            if (aVal == null) return 1;
            if (bVal == null) return -1;
            if (aVal < bVal) return -1 * multiplier;
            if (aVal > bVal) return 1 * multiplier;
            return 0;
        });
    }

    handleExport() {
        const headers = [
            'Opportunity Name', 'Account', 'Amount', 'Close Date', 'Stage',
            'Cancelled Date', 'Changed By', 'Previous Stage', 'Owner'
        ];

        const rows = this.filteredData.map(opp => [
            `"${(opp.name || '').replace(/"/g, '""')}"`,
            `"${(opp.accountName || '').replace(/"/g, '""')}"`,
            opp.amount != null ? opp.amount : '',
            opp.closeDate || '',
            `"${(opp.stageName || '').replace(/"/g, '""')}"`,
            opp.cancelledDate
                ? new Intl.DateTimeFormat('en-US', {
                    year: 'numeric', month: 'short', day: '2-digit',
                    hour: '2-digit', minute: '2-digit'
                  }).format(new Date(opp.cancelledDate))
                : '',
            `"${(opp.cancelledBy || '').replace(/"/g, '""')}"`,
            `"${(opp.previousStage || '').replace(/"/g, '""')}"`,
            `"${(opp.ownerName || '').replace(/"/g, '""')}"`
        ]);

        const csvContent = [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
        const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.setAttribute('download', 'cancelled-opportunities.csv');
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
    }
}
