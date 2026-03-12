public class EnviarBilhetePDF {

    @InvocableMethod(label='Enviar Bilhete PDF por Email' description='Gera o PDF da Visualforce e anexa num email')
    public static void enviarEmailFlow(List<Id> bilheteIds) {
        enviarEmailFuturo(bilheteIds);
    }

    @future(callout=true)
    public static void enviarEmailFuturo(List<Id> bilheteIds) {
        
        // Agora sim: Account__r.PersonEmail!
        List<Bilhete__c> bilhetes = [SELECT Id, Name, Account__r.FirstName, Account__r.LastName, Account__r.PersonEmail FROM Bilhete__c WHERE Id IN :bilheteIds];
        
        List<Messaging.SingleEmailMessage> emailsParaEnviar = new List<Messaging.SingleEmailMessage>();

        for (bilhete__c bilhete : bilhetes) {
            
            PageReference pdfPage = Page.GerarBilhetePDF; 
            pdfPage.getParameters().put('id', bilhete.Id);
            
            Blob pdfBlob;
            if(Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Teste de PDF');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }

            Messaging.EmailFileAttachment anexo = new Messaging.EmailFileAttachment();
            anexo.setFileName('Bilhete_Oficial_' + bilhete.Name + '.pdf');
            anexo.setBody(pdfBlob);
            anexo.setContentType('application/pdf');

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();

            String emailCliente = Bilhete.Account__r.PersonEmail; 
            
            if (String.isNotBlank(emailCliente)) {
                email.setToAddresses(new String[] { emailCliente });
                email.setSubject('O teu Bilhete Oficial - ' + bilhete.Name);
                email.setPlainTextBody('Olá ' + bilhete.Account__r.FirstName + bilhete.Account__r.LastName + ',\n\nO teu lugar está garantido!\n\nEnviamos em anexo o teu Bilhete Eletrónico Oficial.\n\nObrigado,\nEquipa de Bilheteira');
                email.setFileAttachments(new Messaging.EmailFileAttachment[] { anexo });

                emailsParaEnviar.add(email);
            }
        }

        if(!emailsParaEnviar.isEmpty()) {
            Messaging.sendEmail(emailsParaEnviar);
        }
    }
}