#/bin/bash
##################################################################################################
##                                     Teste de conectividade                                   ##
##                                                                                              ##
##  Verifica se existe conectividade entre a maquina local e os IPs e portas                    ##
##  Configuradas                                                                                ##
##                                                                                              ##
##  Chamada exemplo: ./testa_servers.sh <arquivo_de_inventario.txt>                             ##
##  o arquivo de inventario devera possuir DADOS separados por TAB e VALORES por virgula        ##
##  Exemplo:                                                                                    ##
##  <DESCRICAO> TAB <IP>,<IP>,<IP> TAB <PORTA>,<PORTA>,<PORTA>                                  ##
##  Salve arquivos UTF-8 para melhor exibicao de saida                                          ##
##                                                                                              ##
##  Data de criacao: 24/09/2019                                                                 ##
##  05/11/2019 - V 1.1 - Abertura do motivo de falha na coluna RESULTADO e adição da coluna de  ##
##               CAUSA POSSIVEL, informando de forma clara onde verificar o possível problema   ##
##  13/01/2020 - V 1.2 - Adição de arquivos temporarios para exibição do resultado final        ##
##               apenas ao término da execução e um contador com o registro atual e total       ##
##  15/01/2020 - V 1.3 - Alteração para ser executado com fork e acelerar os resultados e       ##
##               Adição da animação enquanto aguarda os processos finalizarem                   ##
##  04/02/2020 - V 1.4 - Alteração pra que o inventario seja tratado antes de processado, desta ##
##               forma, um inventario com formatacao de windows não mais irá quebrar a exibição ##
##               dos resultados dos testes.                                                     ##
##                                                                                              ##
##  Eduardo Paredes                                                                             ##
##################################################################################################

# parametro para definição do timeout da conexão. 10 segundos é um bom valor para testes em VPN.
CONNTIMEOUT="10";

check_update(){

	LASTVERSION=`curl -scL https://raw.githubusercontent.com/eloparedes/test-servers/master/testa_servers.sh |wc -c`;
	THISVERSION=`wc -c $0 |awk '{ print $1 }'`;

	if [[ ${LASTVERSION} != ${THISVERSION} ]]; then
		echo "Seu script está desatualizado, deseja atualizar? S/N";
		read RESPOSTA;

		case ${RESPOSTA} in
			s|S)
				echo "resposta positiva"
				curl -scL https://raw.githubusercontent.com/eloparedes/test-servers/master/testa_servers.sh > update.txt
			;;
			n|N)
				echo "ok, sem atualizar entao";
			;;
			*)
				echo "não encontrei a resposta";
				exit 1;
			;;
		esac

	fi

	#exit 0;
	
}

escreve_update(){
	if [[ ${4} = "UPDATE" ]]; then
		tput cup $((LINES-2)) 0
	else
		tput cup $((LINES-1)) 0
	fi

	IMPR="%-${ICONSIZE}s %-10s %-1s"
	printf "$IMPR\n" "${1}" "${2}" "${3}";
}

escreve_acao(){
	# Cria o primeiro parametro do comando print padronizado
	if [[ ${7} = "OK" ]]; then
		IMPR="%s %-${ICONSIZE}s %s ${GREEN}%-${DESCSIZE}s${NORMAL} %s %-${IPSIZE}s %s %-${PORTSIZE}s %s ${GREEN}%-${RESULTSIZE}s${NORMAL} %s %-${RAIZSIZE}s %s"
	elif [[ ${7} = "FALHA" ]]; then
		IMPR="%s %-${ICONSIZE}s %s ${RED}%-${DESCSIZE}s${NORMAL} %s %-${IPSIZE}s %s %-${PORTSIZE}s %s ${RED}%-${RESULTSIZE}s${NORMAL} %s %-${RAIZSIZE}s %s"
	elif [[ ${7} = "ATENCAO" ]]; then
		IMPR="%s %-${ICONSIZE}s %s ${YELLOW}%-${DESCSIZE}s${NORMAL} %s %-${IPSIZE}s %s %-${PORTSIZE}s %s ${YELLOW}%-${RESULTSIZE}s${NORMAL} %s %-${RAIZSIZE}s %s"
	else
		IMPR="%s %-${ICONSIZE}s %s %-${DESCSIZE}s %s %-${IPSIZE}s %s %-${PORTSIZE}s %s %-${RESULTSIZE}s %s %-${RAIZSIZE}s %s"
	fi
	
	# Imprime o que foi enviado junto com o parametro criado nas linhas acima		
	printf "$IMPR\n" "|" "${1}" "|" "${2}" "|" "${3}" "|" "${4}" "|" "${5}" "|" "${6}" "|";
}

testa(){
	# verifica os IPS e PORTAS da lista por conectividade e imprime na tela
	DESCRICAO="$1"
	IPTESTE="$2"
	PORTATESTE="$3"
	RESP=''
	
	# atualiza a tela
	escreve_update "🔁" "Testando inventario" "${LINHA}/${FSIZE}" "UPDATE"

	if [ -n "${PORTATESTE}" ]; then
		# nc é um comando nao nativo, pode ser necessário instalar
		# para reduzir o tempo de espera para conexao, mudar o parametro G (em segundos) para MacOS
		# ou w (em segundos) para linux

		if [ "${SO}" = "Linux" -o "${SO}" = "CYGWIN" ]; then
			nc -v -z -w${CONNTIMEOUT} ${IPTESTE} ${PORTATESTE} 1>${TESTE} 2>${TESTE}
		elif [[ "${SO}" = "Darwin" ]]; then
			nc -v -z -G${CONNTIMEOUT} ${IPTESTE} ${PORTATESTE} 1>${TESTE} 2>${TESTE}
		else
			nc -v -z ${IPTESTE} ${PORTATESTE} 1>${TESTE} 2>${TESTE}
		fi

		if [ "$?" = "0" ]; then
			TIPO="OK"
			RESP="SUCESSO"
			ICON="✅"
			RAIZ=" "
		else
			REASON=`cat ${TESTE} | awk -F"failed: " '{ print $2 }'`
			REFUSED=`echo ${REASON} |egrep -c "rejected|refused"`
			if [ "${REFUSED}" -gt 0 ]; then
				TIPO="ATENCAO"
				ICON="🔶"
				RAIZ="Aplicacao"
			else
				TIPO="FALHA"
				ICON="🚫"
				RAIZ="Firewall"
			fi			
			RESP+="${TIPO} - ${REASON}"
		fi
		# imprime a string no arquivo
		escreve_acao "${ICON}" "${DESCRICAO}" "${IPTESTE}" "${PORTATESTE}" "${RESP}" "${RAIZ}" "${TIPO}" >> ${TESTRESULTSBODY}
	fi
}

cria_cabecalho(){

	# cria uma linha pontilhada para ser desenhada na saida com o mesmo tamanho da escrita
	for i in $(seq $COLSIZE); do LINE+="-" ; done

	# Imprime o cabecalho do script	
	printf "%s\n"                                   "$LINE" > ${TESTRESULTS}
	printf "%s %-$((COLSIZE-4))s %s\n"                  "|" "Script de teste para regras de Firewall" "|" >> ${TESTRESULTS}
	printf "%s %-$((COLSIZE-4))s %s\n"                  "|" "Eduardo Paredes - 24/09/2019" "|" >> ${TESTRESULTS}
	printf "%s %-$((COLSIZE-4))s %s\n"                  "|" "Execucao em: $DATA" "|" >> ${TESTRESULTS}
	printf "%s\n"                                   "$LINE" >> ${TESTRESULTS}
	escreve_acao "" "DESCRICAO" "IP" "PORTA" "RESULTADO" "CAUSA POSSIVEL" "" "" >> ${TESTRESULTS}
	printf "%s\n"                                   "$LINE" >> ${TESTRESULTS}
}

ciclo_de_testes(){	
	# inicia repeticao de acordo com o tamanho do inventario
	for LINHA in $(seq $FSIZE); do

		# busca dados DESCRICAO, IP e PORTA do inventario
		DESCRICAO=`cat ${DADOS} |awk "NR==${LINHA}" |awk -F'\t' '{ print $1 }'`
		IP=`cat ${DADOS} |sed 's/\ //g' |awk "NR==${LINHA}" |awk -F'\t' '{ print $2 }'`
		PORTA=`cat ${DADOS} |sed 's/\ //g' |awk "NR==${LINHA}" |awk -F'\t' '{ print $3 }'`

		# tratamento para caso o campo IP possua mais de um ip separado por virgula
		# conta quantos sao os valores, pega somente o primeiro e remove da string original
		COMPOSITEIP=`echo $IP |sed 's/[0-9]//g' |sed 's/\.//g' |sed 's/\ //g'`;
		COMPOSITEIP=`echo ${#COMPOSITEIP}`;

		# tratamento para caso o campo PORTA possua mais de uma PORTA separada por virgula
		# conta quantos sao os valores, pega somente o primeiro e remove da string original
		COMPOSITEPORT=`echo $PORTA |sed 's/[0-9]//g' |sed 's/\.//g' |sed 's/\ //g'`
		COMPOSITEPORT=`echo ${#COMPOSITEPORT}`;

		# caso o ip seja composto (mais de um valor)
		if [[ $COMPOSITEIP -gt 0 ]]; then
			# define quantas repeticoes sao necessarias
			IPSEQ=$((COMPOSITEIP+1));
			# inicia as repeticoes
			for I in $(seq $IPSEQ); 
				do
					# caso a porta seja composta - mais de um valor
					if [[ ${COMPOSITEPORT} -gt 0 ]]; then
						# define quantas repeticoes sao necessarias
						PORTSEQ=$((COMPOSITEPORT+1));
						
						# busca somente o primeiro valor da string de IPs
						IPATUAL=`echo $IP |awk -F"," '{ print $1 }'`
						
						# remove o valor buscado da lista de IPS
						IP=${IP#*,}

						# inicia a repeticao das portas
						for J in $(seq $PORTSEQ);
							do				
								# busca a primeira porta da string de portas
								PORTAATUAL=`echo ${PORTA} |awk -F"," '{ print $1 }'`

								# remove o valor buscado da lista de portas
								PORTA=${PORTA#*,}

								# realiza o teste de conectividade chamando a funcao testa
								(testa "$DESCRICAO" "$IPATUAL" "$PORTAATUAL") &
							done
							# retorna o valor da lista de portas para o original para seguir com o proximo ip da lista
							PORTA=`cat ${DADOS} |awk "NR==${LINHA}" |awk -F'\t' '{ print $3 }'`
					else
						# caso a porta nao seja composta porem o IP sim, pega o primeiro da lista
						IPATUAL=`echo $IP |awk -F"," '{ print $1 }'`

						# remove o valor buscado da lista
						IP=${IP#*,}
						
						# realiza o teste de conectividade com o IP buscado da lista e a porta direto do inventario
						(testa "$DESCRICAO" "$IPATUAL" "$PORTA") &
					fi
				done
		# caso a porta seja composta porem o IP nao seja
		elif [[ ${COMPOSITEPORT} -gt 0 ]]; then
			# define quantas repeticoes sao necessarias
			PORTSEQ=$((COMPOSITEPORT+1));

			# inicia a repeticao das portas
			for J in $(seq $PORTSEQ);
				do				
					# busca a primeira porta da string de portas
					PORTAATUAL=`echo ${PORTA} |awk -F"," '{ print $1 }'`

					# remove o valor buscado da lista de portas
					PORTA=${PORTA#*,}

					# realiza o teste de conectividade chamando a funcao testa
					(testa "$DESCRICAO" "$IP" "$PORTAATUAL") &
				done
		else
			# caso nem o ip nem a porta sejam compostos, testa com os valores que buscou do inventario
			(testa "$DESCRICAO" "$IP" "$PORTA") &
		fi
	done 
}

animacao(){
	# salva o pid desta execução
	local pid=$!
	# verifica se o pid desta execução e os pids todos dos testes terminaram de executar enquanto exibe uma animação
	while [ "$(ps a | awk '{print $1}' | grep $pid)" -o "$(ps -ef |grep "nc -v" |grep -v grep)" -o "$(ps -ef |grep /usr/bin/nc |grep -v grep)" ]; do
		for N in ⠛ ⠙ ⠹ ⠽ ⠧ ⠟ ; do 
			printf "\rExecutando: $N"; 
			sleep .2;
		done
	done
}


####### Inicio do script
## 
echo 
# garantir que um parametro foi enviado para este script
if [ $# -lt 1 ]; then
	echo "ERRO: Nenhum parametro foi enviado.";
	echo "USAGE: utilizar $0 <arquivo_de_inventario.txt>";
	exit 1;
elif [[ ! -e ${1} ]]; then
	echo "ERRO: o arquivo enviado nao existe.";
	echo "USAGE: utilizar $0 <arquivo_de_inventario.txt>";
	exit 1;
elif [[ ! -s ${1} ]]; then
	echo "ERRO: o arquivo enviado esta vazio.";
	echo "USAGE: utilizar $0 <arquivo_de_inventario.txt>";
	exit 1;
fi

# Verificação do sistema operacional
SO=`uname |awk -F"_" '{ print $1 }'`
# criação de arquivos temporários para salvar dados da execução
DADOS=$(mktemp);
TESTE=$(mktemp);
TESTRESULTS=$(mktemp);
TESTRESULTSBODY=$(mktemp);
# verificando data atual
DATA=`date +'%d/%m/%Y %T'`

# limpeza do inventario
if [ "${SO}" = "CYGWIN" ]; then
	dos2unix -u ${1}
elif [ "${SO}" = "Linux" -o "${SO}" = "Darwin" ]; then
	dos2unix -q ${1}
fi

cat ${1} |iconv -t UTF-8//TRANSLIT |sed 's/\\r//g' |sed "y/àáâãéêíóôõúç/aaaaeeiooouc/" |sed '/^#/d' |sed '/^$/d' |sed '/^\ $/d'  > ${DADOS}

# definição de cores
RED="\\e[31;1m"
GREEN="\\e[32;1m"
YELLOW="\\e[33;1m"
BLUE="\\e[36;1m"
NORMAL="\\e[m"

# definicao de tamanho da tela para escrever sempre no fim
LINES=`tput lines`
if [ -z ${LINES} ]; then
	LINES=30
fi
# colocando o ponteiro no fim da tela
tput cup ${LINES} 0

###
# Tamanho dos campos para ajuste do output
# pq +21? é o tamanho ocupado pelos espaços e "|" entre as strings anviadas, 
# precisa contar na linha da definição da $IMPR dentro da funcao escreve_acao
ICONSIZE="2"
DESCSIZE="60"
IPSIZE="16"
PORTSIZE="6"
RESULTSIZE="35"
RAIZSIZE="15"
COLSIZE=$((ICON+DESCSIZE+IPSIZE+RESULTSIZE+PORTSIZE+RAIZSIZE+21))

# verifica quantas linhas possui o inventario para repeticao
FSIZE=`awk 'END{print NR}' ${DADOS}`

check_update
# escreve cabeçalho da execução dentro do arquivo temporario
cria_cabecalho

# executa os testes ip por ip e salva o resultado num arquivo temporario.
ciclo_de_testes

# enquanto estiver executando o teste, a animação verifica se terminou.
animacao

# limpar a linha da animação e do contador
tput cup $((LINES-2)) 0

# imprimir os resultados na tela
cat ${TESTRESULTS}
cat ${TESTRESULTSBODY} |sort -ib -t'|' -k 4,4n -k 3,3d -k 5,5n 

# limpeza de arquivos temporários
rm -f ${TESTE} ${DADOS} ${TESTRESULTS} ${TESTRESULTSBODY}

#imprime uma linha final e sai do script
printf "%s\n"                                   "$LINE"

