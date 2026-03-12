public class AleatorioGatewayID {

    @InvocableMethod(label='Gerar ID de Gateway' description='Gera um código alfanumérico aleatório para simular um pagamento')
    public static List<String> gerarID() {
        String codigoAleatorio = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 10).toUpperCase();
        String gatewayIdFinal = 'GW-' + codigoAleatorio; 
        return new List<String>{ gatewayIdFinal };
    }
}