public without sharing class BilhetePDFController {
    public PageReference redirect() {
        String idParam = ApexPages.currentPage().getParameters().get('id');
        if (String.isBlank(idParam)) return null;

        try {
            Id recordId = (Id)idParam;
            String sObjType = recordId.getSObjectType().getDescribe().getName();

            if (sObjType == 'Order') {
                // Se for uma Order, procura o primeiro bilhete associado
                List<Bilhete__c> bilhetes = [SELECT Id FROM Bilhete__c WHERE Order__c = :recordId LIMIT 1];
                if (!bilhetes.isEmpty()) {
                    PageReference pr = new PageReference('/apex/GerarBilhetePDF');
                    pr.getParameters().put('id', bilhetes[0].Id);
                    pr.setRedirect(true);
                    return pr;
                }
            } else if (sObjType == 'Bilhete__c') {
                // Se já for um Bilhete, vai direto
                PageReference pr = new PageReference('/apex/GerarBilhetePDF');
                pr.getParameters().put('id', recordId);
                pr.setRedirect(true);
                return pr;
            }
        } catch (Exception e) {
            System.debug('>>> Erro no redirect de PDF: ' + e.getMessage());
        }

        return null;
    }
}
