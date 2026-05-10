public without sharing class EnviarBilhetePDF {

    @InvocableMethod(label='Enviar Bilhete PDF por Email' description='Gera o PDF da Visualforce e anexa num email')
    public static void enviarEmailFlow(List<Id> bilheteIds) {
        enviarEmailFuturo(bilheteIds);
    }

    @future(callout=true)
    public static void enviarEmailFuturo(List<Id> bilheteIds) {
        if (bilheteIds == null || bilheteIds.isEmpty()) return;

        // 1. Busca os bilhetes e agrupa por Ordem para evitar enviar múltiplos emails
        List<Bilhete__c> bilhetes = [
            SELECT Id, Name, Order__c, Account__r.FirstName, Account__r.LastName, Account__r.PersonEmail 
            FROM Bilhete__c 
            WHERE Id IN :bilheteIds
        ];
        
        Map<Id, List<Bilhete__c>> orderToBilhetes = new Map<Id, List<Bilhete__c>>();
        for (Bilhete__c b : bilhetes) {
            if (b.Order__c != null) {
                if (!orderToBilhetes.containsKey(b.Order__c)) {
                    orderToBilhetes.put(b.Order__c, new List<Bilhete__c>());
                }
                orderToBilhetes.get(b.Order__c).add(b);
            }
        }

        List<Messaging.SingleEmailMessage> emailsParaEnviar = new List<Messaging.SingleEmailMessage>();

        for (Id orderId : orderToBilhetes.keySet()) {
            List<Bilhete__c> ticketsDaOrdem = orderToBilhetes.get(orderId);
            Bilhete__c primeiro = ticketsDaOrdem[0];
            String emailCliente = primeiro.Account__r.PersonEmail;

            if (String.isBlank(emailCliente)) continue;

            // 2. Gera o PDF usando a página Pública que aceita ID de Ordem para gerar todos de uma vez
            PageReference pdfPage = new PageReference('/apex/GerarBilhetePublicoPDF'); 
            pdfPage.getParameters().put('id', orderId);
            
            Blob pdfBlob;
            try {
                if(Test.isRunningTest()) {
                    pdfBlob = Blob.valueOf('Teste de PDF');
                } else {
                    pdfBlob = pdfPage.getContentAsPDF();
                }
            } catch (Exception e) {
                System.debug('Erro ao gerar PDF: ' + e.getMessage());
                continue;
            }

            Messaging.EmailFileAttachment anexo = new Messaging.EmailFileAttachment();
            anexo.setFileName('Bilhetes_GLOBAZ_Order_' + orderId + '.pdf');
            anexo.setBody(pdfBlob);
            anexo.setContentType('application/pdf');

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[] { emailCliente });
            
            String nomeFormatado = (primeiro.Account__r.FirstName != null ? primeiro.Account__r.FirstName + ' ' : '') + 
                                  (primeiro.Account__r.LastName != null ? primeiro.Account__r.LastName : '');
            
            email.setSubject('🎫 Os teus Bilhetes GLOBAZ chegaram!');
            email.setPlainTextBody('Olá ' + nomeFormatado + ',\n\n' +
                'Obrigado pela tua compra! O teu lugar está garantido.\n\n' +
                'Enviamos em anexo o teu Bilhete Eletrónico Oficial (contém ' + ticketsDaOrdem.size() + ' lugar(es)).\n\n' +
                'Diverte-te no evento!\n\n' +
                'Equipa GLOBAZ Tickets');
            
            email.setFileAttachments(new Messaging.EmailFileAttachment[] { anexo });
            emailsParaEnviar.add(email);
        }

        if(!emailsParaEnviar.isEmpty()) {
            Messaging.sendEmail(emailsParaEnviar);
        }
    }
}