public without sharing class AgentCriarReservaAgent {

    public class Input {
        @InvocableVariable(label='eventoId' required=true)
        public String eventoId;

        @InvocableVariable(label='accountId' required=false)
        public String accountId;

        @InvocableVariable(label='metodoPagamento' required=true)
        public String metodoPagamento;

        @InvocableVariable(label='nomeCompleto' required=true)
        public String nomeCompleto;

        @InvocableVariable(label='email' required=false)
        public String email;
    }

    public class Output {
        @InvocableVariable(label='Order ID criada')
        public String orderId;

        @InvocableVariable(label='Account ID (Dono da Reserva)')
        public String reservaAccountId;

        @InvocableVariable(label='Sucesso?')
        public Boolean sucesso;

        @InvocableVariable(label='Mensagem para o chat')
        public String mensagemChat;

        @InvocableVariable(label='Erro')
        public String erroMsg;
    }

    @InvocableMethod(
        label       = 'Agente — Criar Reserva'
        description = 'Cria uma Order Draft para o evento selecionado, após confirmação do utilizador. Faz o callout HTTP ao gateway de pagamento.'
        category    = 'GLOBAZ Tickets'
        callout     = true
    )
    public static List<Output> criarReserva(List<Input> inputs) {
        Output out = new Output();
        try {
            Input inp = inputs[0];

            Id evId;
            try {
                evId = (Id) inp.eventoId;
            } catch (Exception e) {
                out.sucesso = false;
                out.erroMsg = 'ID_EVENTO_INVALIDO';
                out.mensagemChat = '⚠️ Erro interno: O ID do evento não é válido. Por favor, reinicia a seleção.';
                return new List<Output>{ out };
            }

            if (String.isBlank(inp.nomeCompleto) || String.isBlank(inp.email)) {
                out.sucesso = false;
                out.erroMsg = 'DADOS_USER_FALTAL';
                out.mensagemChat = '⚠️ Preciso que indiques o teu nome e e-mail para finalizar a reserva como convidado.';
                return new List<Output>{ out };
            }

            Id accIdVal = String.isNotBlank(inp.accountId) ? (Id) inp.accountId : null;

            String emailSanitized = (inp.email != null) ? inp.email.trim().toLowerCase() : '';

            // Reutilizar lógica existente do BilheteiraController
            String resultado = BilheteiraController.criarReserva(
                evId,
                accIdVal,
                inp.metodoPagamento,
                inp.nomeCompleto,
                emailSanitized
            );

            if (resultado == 'PAGAMENTO_RECUSADO') {
                out.sucesso      = false;
                out.erroMsg      = 'PAGAMENTO_RECUSADO';
                out.mensagemChat = '❌ O pagamento foi recusado pelo sistema. '
                    + 'Queres tentar com outro método de pagamento?';
                return new List<Output>{ out };
            }

            if (resultado.startsWith('ERRO:')) {
                out.sucesso      = false;
                out.erroMsg      = resultado;
                out.mensagemChat = '⚠️ Ocorreu um erro: ' + resultado.replace('ERRO: ', '')
                    + '\nTenta novamente ou contacta o suporte.';
                return new List<Output>{ out };
            }

            // Sucesso — resultado é o ID da Order
            out.sucesso      = true;
            out.orderId      = resultado;
            
            // Buscar o AccountId associado à Order (pode ser o guest account recém-criada)
            List<Order> ords = [SELECT AccountId FROM Order WHERE Id = :resultado LIMIT 1];
            if (!ords.isEmpty()) {
                out.reservaAccountId = ords[0].AccountId;
            }
            
            out.mensagemChat = '✅ Reserva criada! A processar o pagamento...';

        } catch (Exception e) {
            out.sucesso      = false;
            out.erroMsg      = e.getMessage();
            out.mensagemChat = '⚠️ Erro inesperado. Por favor tenta novamente.';
        }
        return new List<Output>{ out };
    }
}