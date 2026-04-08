public without sharing class AgentProcessarPagamento {

    public class Input {
        @InvocableVariable(label='Order ID' required=true)
        public String orderId;

        @InvocableVariable(label='ID do Evento' required=true)
        public String eventoId;

        @InvocableVariable(label='Tipo de bilhete' required=true)
        public String tipoBilhete;

        @InvocableVariable(label='Quantidade' required=true)
        public Decimal quantidade;

        @InvocableVariable(label='Fila' required=false)
        public String fila;

        @InvocableVariable(label='Lugar' required=false)
        public Decimal lugar;
    }

    public class Output {
        @InvocableVariable(label='Sucesso?')
        public Boolean sucesso;

        @InvocableVariable(label='Mensagem para o chat')
        public String mensagemChat;

        @InvocableVariable(label='Número de bilhetes criados')
        public Decimal totalBilhetes;

        @InvocableVariable(label='Erro')
        public String erroMsg;
    }

    @InvocableMethod(
        label       = 'Agente — Processar Pagamento e Criar Bilhetes'
        description = 'Confirma o pagamento com o gateway, cria os Bilhete__c e ativa a Order. Deve ser chamado após AgentCriarReservaAgent.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> processarPagamento(List<Input> inputs) {
        Output out = new Output();
        try {
            if (inputs == null || inputs.isEmpty()) {
                out.sucesso = false;
                out.erroMsg = 'Sem dados de entrada.';
                return new List<Output>{ out };
            }

            Input inp = inputs[0];

            Id ordId = (Id) inp.orderId;
            Id evId  = (Id) inp.eventoId;

            // Construir JSON de bilhetes baseado nos inputs simples (conforme YAML)
            String codigoBilhete = inp.tipoBilhete;
            if (codigoBilhete != null) {
                if (codigoBilhete.equalsIgnoreCase('Geral'))    codigoBilhete = 'BLT-Geral';
                else if (codigoBilhete.equalsIgnoreCase('VIP'))  codigoBilhete = 'BLT-VIP';
                else if (codigoBilhete.equalsIgnoreCase('Camarote')) codigoBilhete = 'BLT-CAMAROTE';
            }

            List<Map<String, Object>> bilhetesList = new List<Map<String, Object>>();
            Integer qtd = (inp.quantidade != null) ? inp.quantidade.intValue() : 1;
            Integer startLugar = (inp.lugar != null) ? inp.lugar.intValue() : 1;

            for(Integer i=0; i < qtd; i++) {
                bilhetesList.add(new Map<String, Object>{
                    'fila'  => (String.isNotBlank(inp.fila) ? inp.fila : 'A'),
                    'lugar' => startLugar + i,
                    'tipo'  => codigoBilhete
                });
            }
            String bilhetesJsonFinal = JSON.serialize(bilhetesList);
            String extrasJsonFinal   = '[]';

            // Reutilizar lógica existente
            String resultado = BilheteiraController.processarPagamentoMock(
                ordId,
                evId,
                bilhetesJsonFinal,
                extrasJsonFinal
            );

            if (resultado == 'PAGAMENTO_OK') {
                // Contar bilhetes criados
                Integer totalBilhetesCriados = [
                    SELECT COUNT() FROM Bilhete__c WHERE Order__c = :ordId
                ];
                out.sucesso       = true;
                out.totalBilhetes = totalBilhetesCriados;

                // Buscar email do cliente para confirmar envio
                List<Order> ords = [
                    SELECT Account.PersonEmail, Account.FirstName
                    FROM   Order WHERE Id = :ordId LIMIT 1
                ];
                String emailCliente = (!ords.isEmpty() && ords[0].Account != null)
                    ? ords[0].Account.PersonEmail : '';
                String nomeCliente = (!ords.isEmpty() && ords[0].Account != null)
                    ? ords[0].Account.FirstName : 'Cliente';

                out.mensagemChat =
                    '🎉 *Compra confirmada, ' + (nomeCliente != null ? nomeCliente : 'Cliente') + '!*\n\n'
                    + '🎫 ' + totalBilhetesCriados + ' bilhete(s) reservado(s) com sucesso.\n'
                    + '📧 O teu bilhete PDF vai chegar ao email *' + (emailCliente != null ? emailCliente : '') + '* em breve.\n\n'
                    + '📱 Guarda o email — precisas dele na entrada do evento.\n'
                    + 'Posso ajudar-te com mais alguma coisa? 😊';

            } else if (resultado == 'PAGAMENTO_RECUSADO') {
                out.sucesso      = false;
                out.erroMsg      = 'PAGAMENTO_RECUSADO';
                out.mensagemChat = '❌ O pagamento foi recusado.\n'
                    + 'Queres tentar com outro método? (MBWay, Cartão, MB, Transferência)';

            } else {
                out.sucesso      = false;
                out.erroMsg      = resultado;
                out.mensagemChat = '⚠️ Erro no processamento: '
                    + (resultado != null ? resultado.replace('ERRO: ', '') : 'Erro desconhecido')
                    + '\nContacta o suporte se o problema persistir.';
            }

        } catch (Exception e) {
            out.sucesso      = false;
            out.erroMsg      = e.getMessage();
            out.mensagemChat = '⚠️ Erro inesperado no pagamento. Tenta novamente.';
        }
        return new List<Output>{ out };
    }
}